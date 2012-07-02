#!/usr/bin/perl

######################################################################
#
# Input Excel must be coverted to Excel 97-2004 Workbook format (.xls)
#
######################################################################

use strict;
use DBI;
use Getopt::Long qw(GetOptions);
use Spreadsheet::ParseExcel;
use ApiCommonWebsite::Model::ModelConfig;

use constant ROWNUM => 6;

binmode(STDOUT, ":utf8"); # deal with special characters, such as β-ketoacyl-ACP reductase 2 (KAR2)

my (%hash, @comments);
my ($input, $commit);

my $review_status_id = 'unknown'; # 'community' is for expert comments
my $comment_target_id = 'gene';

GetOptions( "inpute=s" => \$input,
            "commit!"  => \$commit,);

my $usage =<<EOL;
Usage: insertBulkUserComments.pl --input bulkUserCommentExcelFile --commit
Where: input  - bulk user comment file in Excel format (MUST in Excel 2000-2004 format .xls)
       commit - do submission

For example
  insertBulkUserComments.pl --input BulkUserComment_Atashi.xls 
EOL

die $usage unless ($input);

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

my $projectId = $hash{0}{1};
my $submitter_email = $hash{2}{1};

my $c = new ApiCommonWebsite::Model::ModelConfig($projectId);

my $dbh = DBI->connect($c->appDb->dbiDsn, $c->appDb->login, $c->appDb->password,
             { RaiseError => 1, AutoCommit => 0 }) || 
             die "Database connection note mode: $DBI::errstr";

my $userDb = DBI->connect($c->userDb->dbiDsn, $c->userDb->login, $c->userDb->password,
             { RaiseError => 1, AutoCommit => 0 }) || 
             die "Database connection note mode: $DBI::errstr";

my ($submitter_id, $email) = &get_submitter_id($submitter_email);

print "email: $email | $projectId | submitter_id $submitter_id\n";

die "There is no user $submitter_email in the database.\n" unless $submitter_id;

while(my ($k, $v) = each %hash) {

  #comments data starts from row 5, k is the row num. the first row is row 0
  next if $k < ROWNUM - 1;   

  my $gene_id  = $hash{$k}{0};
  my $headline = $hash{$k}{1};
  my $content  = $hash{$k}{2};
  my $category = $hash{$k}{3};
  my $location = $hash{$k}{4};
  my $pmid     = $hash{$k}{5};
  my $doi      = $hash{$k}{6};

  my $genbank_acc      = $hash{$k}{7};
  my $associated_genes = $hash{$k}{8};

  $content .= "\nLocation: $location" if $location;

  $gene_id =~ s/\s+$//g;
  $pmid =~ s/\s+//g;
  $pmid =~ s/;/,/g;

  my $sql = <<EOSQL;
SELECT gf.source_id, bfmv.start_min, bfmv.end_max, bfmv.strand,
       etb.name, etr.version, bfmv.project_id,
       bfmv.species as organism, bfmv.sequence_id as contig
FROM   DoTS.GeneFeature gf, ApiDBTuning.GeneAttributes bfmv,
       ApiDBTuning.GeneID gi, DoTS.ExternalNASequence nas,
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

  my $comment = {
     gene_id => $gene_id,
     pmid    => $pmid,
     doi     => $doi,
     headline => $headline,
     content  => $content,
     category => $category,
     genbank_acc => $genbank_acc,
     associated_genes => $associated_genes,
    };

  push @row, $comment;
  push @comments, \@row;
}

foreach(@comments) {
  my($source_id, $start, $end, $strand, $db_name, $db_version, $project_id, $organism, $contig, $comment) = @$_;
  print "$source_id, $start, $end, $strand, $db_name, $db_version, $project_id, $organism, $contig\n ";

  my $is_reverse = $strand =~ /forward/ ? 0 : 1;
  my $pmid = $comment->{pmid};
  my $doi = $comment->{doi};
  my $headline = $comment->{headline};
  my $content =  $comment->{content};
  my $category = $comment->{category};
  my $associated_genes = $comment->{associated_genes};

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
  }

  my $location_string = "genome: $contig:$start-$end ($strand strand)";

  my $sql = "SELECT comments2.comments_pkseq.nextval as comment_id from dual";
  my $sth = $userDb->prepare($sql);
  $sth->execute;
  my ($comment_id) = $sth->fetchrow_array;

  my $sql = "SELECT comments2.external_databases_pkseq.nextval as external_database_id from dual";
  my $sth = $userDb->prepare($sql);
  $sth->execute;
  my ($external_database_id) = $sth->fetchrow_array;


  $sql =<<EOL;
INSERT INTO comments2.comments (comment_id, email, comment_date, 
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
INSERT INTO comments2.locations 
       (comment_id, location_id, location_start, location_end, is_reverse, coordinate_type) 
VALUES ($comment_id, comments2.locations_pkseq.nextval, $start, $end, $is_reverse, 'genome')
EOL
  $userDb->do($sql) if $commit;

  $sql =<<EOL;
INSERT INTO comments2.external_databases 
    (external_database_id, external_database_name, external_database_version) 
    VALUES ($external_database_id, '$db_name', '$db_version')
EOL
  $userDb->do($sql) if $commit;

  $sql =<<EOL;
INSERT INTO comments2.comment_external_database 
     (external_database_id, comment_id) 
VALUES ($external_database_id, $comment_id)
EOL

  $userDb->do($sql) if $commit;


  $sql =<<EOL;
INSERT INTO comments2.CommentTargetCategory 
       (comment_target_category_id, comment_id, target_category_id )
VALUES (comments2.commentTargetCategory_pkseq.nextval, $comment_id, $target_category_id)
EOL
  $userDb->do($sql) if $commit;

  $associated_genes =~ s/\s+$//g;
  $associated_genes =~ s/\,$//g;
  if($associated_genes) {

    my @genes = split/\,/, $associated_genes;
    foreach my $gene (@genes) {
      $gene =~ s/\s+//g;
      $sql =<<EOL;
INSERT INTO comments2.CommentStableId 
        (comment_stable_id, stable_id, comment_id)
VALUES (comments2.commentStableId_pkseq.nextval, '$gene', $comment_id)
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
INSERT INTO comments2.CommentReference 
        (comment_reference_id, source_id, database_name, comment_id)
VALUES (comments2.commentReference_pkseq.nextval, $id, 'pubmed', $comment_id)
EOL
      $userDb->do($sql) if $commit;
    }
  }

  if($doi) {
  
  $sql =<<EOL;
INSERT INTO comments2.CommentReference 
        (comment_reference_id, source_id, database_name, comment_id)
VALUES (comments2.commentReference_pkseq.nextval, $doi, 'doi', $comment_id)
EOL
    $userDb->do($sql) if $commit;
  }


=c
INSERT INTO comments2.CommentFile (file_id, name, notes, comment_id)
VALUES (?, ?, ?, ?)");

INSERT INTO comments2.CommentSequence (comment_sequence_id, sequence, comment_id)
VALUES (?, ?, ?)
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
