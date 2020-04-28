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
  #die 'This file has broken or unreviewed GUS4_STATUS rules.  Please remove this line when all are fixed or absent';
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^

use strict;
use DBI;
use DBD::Oracle qw(:ora_types);
use Getopt::Long qw(GetOptions);
use WDK::Model::ModelConfig;


my (%hash, @comments);
my ($input, $project_id, $submitter_email, $review_status_id, $commit);

my $comment_target_id = 'gene';

GetOptions( "inpute=s"           => \$input,
            "project_id=s"       => \$project_id,
            "submitter_email=s"  => \$submitter_email,
            "review_status_id=s" => \$review_status_id,
            "commit!"            => \$commit);

print "commit: $commit\n";

my $usage =<<EOL;
Usage: insertBulkUserComments.pl --input bulkUserCommentExcelFile --commit
Where: input  - bulk user comment file in Excel format (MUST in Excel 2000-2004 format .xls)
       projet_id  - ToxoDB / PlasmoDB / TriTrypDB / ...
       review_status_id - 'unknown' is the default and 'community' is for expert comments
       commit - do submission

For example
  insertBulkUserComments.pl --input BulkUserComment_Atashi.xls --project_id ToxoDB --review_status_id community 
EOL

die $usage unless ($input && $project_id && $submitter_email && $review_status_id);

my @other_authors = ();

print "## $submitter_email \n";
print "## other authors @other_authors\n";

my $c = new WDK::Model::ModelConfig($project_id);

my $dbh = DBI->connect($c->appDb->dbiDsn, $c->appDb->login, $c->appDb->password,
             { RaiseError => 1, AutoCommit => 0 }) || 
             die "Database connection note mode: $DBI::errstr";

my $userDb = DBI->connect($c->userDb->dbiDsn, $c->userDb->login, $c->userDb->password,
             { RaiseError => 1, AutoCommit => 0 }) || 
             die "Database connection note mode: $DBI::errstr";

my $accountDb = DBI->connect($c->accountDb->dbiDsn, $c->accountDb->login, $c->accountDb->password,
             { RaiseError => 1, AutoCommit => 0 }) || 
             die "Database connection note mode: $DBI::errstr";

$accountDb->{LongReadLen} = 512*1024;
$accountDb->{LongTruncOk} = 1;

my ($submitter_id, $email) = &get_submitter_id($submitter_email);

print "email: $email | $project_id | submitter_id $submitter_id\n";

die "There is no user $submitter_email in the database.\n" unless $submitter_id;

print "input: $input\n";

open(IN, $input);
while(<IN>){
  chomp;
  next if /^#/;

  my ($gene_id, $headline, $content, $category, $loc, $pmid, $doi, $genbank_acc, $associated_genes, @misc) = split /\t/, $_;
  
  my $seq = ""; 

  $category = "function" unless $category;
  $gene_id =~ s/\s//g;
  $content =~ s/^"//;
  $content =~ s/"$//;
  $pmid    =~ s/PMID:\s+//i;

  $associated_genes =~ s/\s+$//g;
  $associated_genes =~ s/\,$//g;
  $associated_genes =~ s/^"//;
  $associated_genes =~ s/"$//;

  my $sql = <<EOSQL;
SELECT gf.source_id, bfmv.start_min, bfmv.end_max, bfmv.is_reversed,
       etb.name, etr.version, 
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
  my ($source_id, $start, $end, $is_reversed, $db_name, $db_version, $organism, $contig) = $sth->fetchrow_array; 


  $sth->finish;
  print "\n\nCannot find $gene_id\n" and die unless $source_id;

	$content .= "Gene ID used in comment: $gene_id;" if ($gene_id ne $source_id);
  my $strand = 'forward';
  $strand = 'reverse' if ($is_reversed == 1);
  my $location_string = "genome: $contig:$start-$end ($strand strand)";

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


print <<EOL;
================================================
Gene ID:         $gene_id 
Source ID:       $source_id
Headline:        $headline 
PMID:            $pmid 
DOI              $doi   
Content:         $content 
Seq:             $seq
GenBank Accs:    $genbank_acc
Associated:      $associated_genes
DB Name:         $db_name
DB Ver:          $db_version
Organism:        $organism
Contig:          $contig
Start:           $start
End:             $end
Is Reversed      $is_reversed
Strand:          $strand
Location:        $location_string
Category:        $category 
Target Category: $target_category_id
================================================

EOL

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
VALUES ($comment_id, userlogins5.locations_pkseq.nextval, $start, $end, $is_reversed, 'genome')
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

  if($associated_genes ne "") {

    my @genes = split/\,|\s/, $associated_genes;
    foreach my $gene (@genes) {
      $gene =~ s/\s+//g;
      next if $gene eq "";
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

  if($doi ne "") {
  
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


  if($genbank_acc ne "") {
  
  $sql =<<EOL;
INSERT INTO userlogins5.CommentReference 
        (comment_reference_id, source_id, database_name, comment_id)
VALUES (userlogins5.commentReference_pkseq.nextval, '$genbank_acc', 'genbank', $comment_id)
EOL
    $userDb->do($sql) if $commit;
  }

  if($seq ne "") {
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

  print "email: $email\n";
  my $sql = "select user_id, email from useraccounts.Accounts where lower(email) = ?";
  my $sth = $accountDb->prepare($sql);
  $sth->execute(lc($email));

  my ($submitter_id, $email) = $sth->fetchrow_array();
  $sth->finish;
  return ($submitter_id, $email);
}
