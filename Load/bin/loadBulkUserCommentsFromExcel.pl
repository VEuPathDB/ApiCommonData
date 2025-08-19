#!/usr/bin/perl
#vvvvvvvvvvvvvvvvvvvvvvvvv GUS4_STATUS vvvvvvvvvvvvvvvvvvvvvvvvv
  # GUS4_STATUS | SRes.OntologyTerm              | auto   | absent
  # GUS4_STATUS | SRes.SequenceOntology          | auto   | absent
  # GUS4_STATUS | Study.OntologyEntry            | auto   | absent
  # GUS4_STATUS | SRes.GOTerm                    | auto   | absent
  # GUS4_STATUS | Dots.RNAFeatureExon            | auto   | absent
  # GUS4_STATUS | RAD.SageTag                    | auto   | absent
  # GUS4_STATUS | RAD.Analysis                   | auto   | absent
  # GUS4_STATUS | ApiDB.Profile                  | auto   | absent
  # GUS4_STATUS | Study.Study                    | auto   | absent
  # GUS4_STATUS | Dots.Isolate                   | auto   | absent
  # GUS4_STATUS | DeprecatedTables               | auto   | absent
  # GUS4_STATUS | Pathway                        | auto   | absent
  # GUS4_STATUS | DoTS.SequenceVariation         | auto   | absent
  # GUS4_STATUS | RNASeq Junctions               | auto   | absent
  # GUS4_STATUS | Simple Rename                  | auto   | absent
  # GUS4_STATUS | ApiDB Tuning Gene              | auto   | broken
  # GUS4_STATUS | Rethink                        | auto   | absent
  # GUS4_STATUS | dots.gene                      | manual | unreviewed
die 'This file has broken or unreviewed GUS4_STATUS rules.  Please remove this line when all are fixed or absent';
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^

######################################################################
#
# Input Excel must be coverted to Excel 97-2004 Workbook format (.xls)
#
######################################################################

use strict;
use DBI;
use DBD::Oracle qw(:ora_types);
use Getopt::Long qw(GetOptions);
use Spreadsheet::ParseExcel;
use ApiCommonWebsite::Model::ModelConfig;

binmode(STDOUT, ":utf8"); # deal with special characters, such as β-ketoacyl-ACP reductase 2 (KAR2)

my (%hash, @comments);
my ($input, $rownum, $project_id, $review_status_id, $commit);

my $comment_target_id = 'gene';

GetOptions( "inpute=s"           => \$input,
            "rownum=i"           => \$rownum,
            "project_id=s"       => \$project_id,
            "review_status_id=s" => \$review_status_id,
            "commit!"            => \$commit,);

my $usage =<<EOL;
Usage: insertBulkUserComments.pl --input bulkUserCommentExcelFile --commit
Where: input  - bulk user comment file in Excel format (MUST in Excel 2000-2004 format .xls)
       rownum - the first row number of the comments in Excel, for example 6
       projet_id  - ToxoDB / PlasmoDB / TriTrypDB / ...
       review_status_id - 'unknown' is the default and 'community' is for expert comments
       commit - do submission

For example
  insertBulkUserComments.pl --input BulkUserComment_Atashi.xls --rownum 6 --project_id ToxoDB --review_status_id community 
EOL

die $usage unless ($input && $rownum && $project_id && $review_status_id);

my $parser = Spreadsheet::ParseExcel->new( CellHandler => \&cell_handler,
                                           NotSetCell  => 1 );

my $workbook = $parser->Parse($input);

sub cell_handler { 
  my $workbook    = $_[0];
  my $sheet_index = $_[1];
  my $row         = $_[2];
  my $col         = $_[3];
  my $cell        = $_[4]; 
            
  # Skip some worksheets and rows (inefficiently).
  return if $sheet_index >= 1;

  my $value = $cell->Value(); 
  $hash{$row}{$col} = $value;
  #print "## row:$row col:$col => $value\n";
} 

my $submitter_email = $hash{2}{5};  # row 3 column F

my @other_authors = ($hash{3}{0}, $hash{4}{0});

print "## $submitter_email \n";
print "## other authors @other_authors\n";

my $c = new ApiCommonWebsite::Model::ModelConfig($project_id);

my $dbh = DBI->connect($c->appDb->dbiDsn, $c->appDb->login, $c->appDb->password,
             { RaiseError => 1, AutoCommit => 0 }) || 
             die "Database connection note mode: $DBI::errstr";

my $userDb = DBI->connect($c->userDb->dbiDsn, $c->userDb->login, $c->userDb->password,
             { RaiseError => 1, AutoCommit => 0 }) || 
             die "Database connection note mode: $DBI::errstr";

$userDb->{LongReadLen} = 512*1024;
$userDb->{LongTruncOk} = 1;


my ($submitter_id, $email) = &get_submitter_id($submitter_email);

print "email: $email | $project_id | submitter_id $submitter_id\n";

die "There is no user $submitter_email in the database.\n" unless $submitter_id;


while(my ($k, $v) = each %hash) {

  #comments data starts from row 5, k is the row num. the first row is row 0
  next if $k < $rownum - 1;   

  my $gene_id   = $hash{$k}{0};  # column 1 A
  my $gene_name  = $hash{$k}{1};  # Column 2 B
  my $function  = $hash{$k}{2};  # Column 3 C
	my $category  = "function";
  my $synonyms  = $hash{$k}{3};  # Column 4 D
  my $location  = $hash{$k}{4};  # Column 5 E
  my $seq       = $hash{$k}{5};  # Column 6 F
  my $pmid      = $hash{$k}{6};  # Column 7 G

  my $genbank_acc      = $hash{$k}{7};  # Column 8 H
  my $associated_genes = $hash{$k}{8};
  my $other_info = $hash{$k}{11}; # Column M
  my $doi      = "";

  my $headline = $gene_name if $gene_name;

	my $content = "";
  $content .= "Gene Name: $gene_name; " if $gene_name;
  $content .= "Function: $function; " if $function;
  $content .= "Synonyms: $synonyms; " if $synonyms;
	$content .= "Cellular Location: $location; " if $location;
	$content .= "Note: $other_info; " if $other_info;

  $gene_id =~ s/\s+$//g;
  $pmid =~ s/\s+//g;
  $pmid =~ s/;/,/g;

  my $sql = <<EOSQL;
SELECT gf.source_id, bfmv.start_min, bfmv.end_max, bfmv.strand,
       etb.name, etr.version, bfmv.project_id,
       bfmv.species as organism, bfmv.sequence_id as contig
FROM   DoTS.GeneFeature gf, webready.GeneAttributes bfmv,
       webready.GeneID gi, DoTS.ExternalNASequence nas,
       SRes.ExternalDatabase etb, SRes.ExternalDatabaseRelease etr
WHERE  gf.na_sequence_id = nas.na_sequence_id
   AND gf.source_id = bfmv.source_id
   AND nas.external_database_release_id = etr.external_database_release_id
   AND etr.external_database_id = etb.external_database_id
   AND gi.gene = gf.source_id
   AND (gf.source_id = '$gene_id' OR gi.id ='$gene_id')
EOSQL

  my $sth = $dbh->prepare($sql);
  $sth->execute;
  my @row = $sth->fetchrow_array; 

  $sth->finish;
  print "cannot find $gene_id\n" and die unless @row;

	$content .= "Gene ID used in comment: $gene_id;" if ($gene_id ne $row[0]);

  my $comment = {
     pmid             => $pmid,
     doi              => $doi,
     headline         => $headline,
     content          => $content,
     seq              => $seq,
     category         => $category,
     genbank_acc      => $genbank_acc,
     associated_genes => $associated_genes,
    };

  push @row, $comment;
  push @comments, \@row;
}

foreach(@comments) {
  my($source_id, $start, $end, $strand, $db_name, $db_version, $project_id, $organism, $contig, $comment) = @$_;

  my $is_reverse = $strand =~ /forward/ ? 0 : 1;
  my $pmid = $comment->{pmid};
  my $doi = $comment->{doi};
  my $headline = $comment->{headline};
  my $content =  $comment->{content};
	my $seq      = $comment->{seq};
  my $category = $comment->{category};
  my $associated_genes = $comment->{associated_genes};
  my $genbank_acc      = $comment->{genbank_acc};

  my $target_category_id = 1;
  if($category =~ /gene/i) {
    $target_category_id = 1;
  } elsif($category =~ /name/i) {
    $target_category_id = 2;
  } elsif($category =~ /function/i) {
    $target_category_id = 3;
  } elsif($category =~ /expression/i) {
    $target_category_id = 4;
  } elsif($category =~ /sequence/i) {
    $target_category_id = 5;
  } elsif($category =~ /phenotype/i) {
    $target_category_id = 6;
  } else {
    $target_category_id = 3;
	}

  my $location_string = "genome: $contig:$start-$end ($strand strand)";

  print "$source_id\nLocation: $location_string\nHeadline: $headline\nContent: $content\nCategory: $category\nAssociated genes:  $associated_genes\nPMID: $pmid\nGenBank: $genbank_acc\nOther authors: @other_authors\nSeq:$seq\n\n ";

  my $sql = "SELECT userlogins5.comments_pkseq.nextval as comment_id from dual";
  my $sth = $userDb->prepare($sql);
  $sth->execute;
  my ($comment_id) = $sth->fetchrow_array;

  my $sql = "SELECT userlogins5.external_databases_pkseq.nextval as external_database_id from dual";
  my $sth = $userDb->prepare($sql);
  $sth->execute;
  my ($external_database_id) = $sth->fetchrow_array;


  $sql =<<EOL;
INSERT INTO userlogins5.comments (comment_id, email, comment_date, 
                                comment_target_id, stable_id, conceptual, 
                                project_name, project_version, headline, 
                                review_status_id, content, location_string, 
                                organism, user_id, is_visible) 
VALUES ($comment_id, '$email', SYSDATE,
        '$comment_target_id', '$source_id', 0, 
        '$project_id', '$db_version', '$headline', 
        '$review_status_id', '$content', '$location_string', 
        '$organism', $submitter_id, 1)
EOL
  $userDb->do($sql) if $commit;

  $sql =<<EOL;
INSERT INTO userlogins5.locations 
       (comment_id, location_id, location_start, location_end, is_reverse, coordinate_type) 
VALUES ($comment_id, userlogins5.locations_pkseq.nextval, $start, $end, $is_reverse, 'genome')
EOL
  $userDb->do($sql) if $commit;

  $sql =<<EOL;
INSERT INTO userlogins5.external_databases 
    (external_database_id, external_database_name, external_database_version) 
    VALUES ($external_database_id, '$db_name', '$db_version')
EOL
  $userDb->do($sql) if $commit;

  $sql =<<EOL;
INSERT INTO userlogins5.comment_external_database 
     (external_database_id, comment_id) 
VALUES ($external_database_id, $comment_id)
EOL

  $userDb->do($sql) if $commit;


  $sql =<<EOL;
INSERT INTO userlogins5.CommentTargetCategory 
       (comment_target_category_id, comment_id, target_category_id )
VALUES (userlogins5.commentTargetCategory_pkseq.nextval, $comment_id, $target_category_id)
EOL
  $userDb->do($sql) if $commit;

  $associated_genes =~ s/\s+$//g;
  $associated_genes =~ s/\,$//g;
  if($associated_genes) {

    my @genes = split/\,|\s/, $associated_genes;
    foreach my $gene (@genes) {
      $gene =~ s/\s+//g;
      $sql =<<EOL;
INSERT INTO userlogins5.CommentStableId 
        (comment_stable_id, stable_id, comment_id)
VALUES (userlogins5.commentStableId_pkseq.nextval, '$gene', $comment_id)
EOL
      $userDb->do($sql) if $commit;
    }
  }

# database_name: doi, pubmed, genbank, author
  if($pmid) {

    $pmid =~ s/\s+//g;
    $pmid =~ s/\,$//g;
    my @ids = split/\,/, $pmid;
    foreach my $id (@ids) {
  
      $sql =<<EOL;
INSERT INTO userlogins5.CommentReference 
        (comment_reference_id, source_id, database_name, comment_id)
VALUES (userlogins5.commentReference_pkseq.nextval, $id, 'pubmed', $comment_id)
EOL
      $userDb->do($sql) if $commit;
    }
  }

  if($doi) {
  
  $sql =<<EOL;
INSERT INTO userlogins5.CommentReference 
        (comment_reference_id, source_id, database_name, comment_id)
VALUES (userlogins5.commentReference_pkseq.nextval, '$doi', 'doi', $comment_id)
EOL
    $userDb->do($sql) if $commit;
  }

  if(@other_authors) {
  
	foreach(@other_authors) {
  $sql =<<EOL;
INSERT INTO userlogins5.CommentReference 
        (comment_reference_id, source_id, database_name, comment_id)
VALUES (userlogins5.commentReference_pkseq.nextval, '$_', 'author', $comment_id)
EOL
    $userDb->do($sql) if $commit;
		}
  }


  if($genbank_acc) {
  
  $sql =<<EOL;
INSERT INTO userlogins5.CommentReference 
        (comment_reference_id, source_id, database_name, comment_id)
VALUES (userlogins5.commentReference_pkseq.nextval, '$genbank_acc', 'genbank', $comment_id)
EOL
    $userDb->do($sql) if $commit;
  }




  if($seq) {
  $sql =<<EOL;
INSERT INTO userlogins5.CommentSequence (comment_sequence_id, sequence, comment_id)
VALUES (userlogins5.commentSequence_pkseq.nextval, ?, ?)
EOL

#VALUES (userlogins5.commentSequence_pkseq.nextval, '$seq', $comment_id)

   my $sth = $userDb->prepare($sql);
    $sth->bind_param(1, $seq,  {ora_type => ORA_CLOB});
    $sth->bind_param(2, $comment_id);

    #$userDb->do($sql) if $commit;
    $sth->execute() if $commit;
		$sth->finish;

	}

=c
INSERT INTO userlogins5.CommentFile (file_id, name, notes, comment_id)
VALUES (?, ?, ?, ?)");

=cut

}

$userDb->disconnect;
$dbh->disconnect;

sub get_submitter_id {
  my $email = shift;
  my $sql = "select user_id, email from userlogins3.users where lower(email) = ?";
  my $sth = $userDb->prepare($sql);
  $sth->execute(lc($email));

  my ($submitter_id, $email) = $sth->fetchrow_array();
  $sth->finish;
  return ($submitter_id, $email);
}
