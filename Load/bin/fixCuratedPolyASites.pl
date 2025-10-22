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
  # GUS4_STATUS | DeprecatedTables               | auto   | broken
  # GUS4_STATUS | Pathway                        | auto   | absent
  # GUS4_STATUS | DoTS.SequenceVariation         | auto   | absent
  # GUS4_STATUS | RNASeq Junctions               | auto   | absent
  # GUS4_STATUS | Simple Rename                  | auto   | absent
  # GUS4_STATUS | ApiDB Tuning Gene              | auto   | broken
  # GUS4_STATUS | Rethink                        | auto   | absent
  # GUS4_STATUS | dots.gene                      | manual | unreviewed
die 'This file has broken or unreviewed GUS4_STATUS rules.  Please remove this line when all are fixed or absent';
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^

## to set UTR_length of curated Poly A Sites

use strict;
use Getopt::Long;
use lib "$ENV{GUS_HOME}/lib/perl";
use GUS::ObjRelP::DbiDatabase;
use GUS::Supported::GusConfig;
use CBIL::Bio::SequenceUtils;

my ($sample,$verbose,$gusConfigFile,$commit);
&GetOptions("verbose|v!"=> \$verbose,
            "gusConfigFile|c=s" => \$gusConfigFile,
            "commit!" => \$commit,
           );

my $gusconfig = GUS::Supported::GusConfig->new($gusConfigFile);
my $db = GUS::ObjRelP::DbiDatabase->new($gusconfig->getDbiDsn(),
                                        $gusconfig->getDatabaseLogin(),
                                        $gusconfig->getDatabasePassword(),
                                        $verbose,0,1,
                                        $gusconfig->getCoreSchemaName());
my $dbh = $db->getQueryHandle();

my $geneStmt = $dbh->prepare(<<SQL);
SELECT source_id, na_sequence_id, decode(strand,'forward','+','reverse','-') as strand,
CASE WHEN coding_start is not null THEN coding_start ELSE CASE WHEN strand = 'forward' THEN start_min ELSE end_max END END as coding_start,
CASE WHEN coding_end is not null THEN coding_end ELSE CASE WHEN strand = 'forward' THEN end_max ELSE start_min END END as coding_end
FROM webready.GeneAttributes_p
WHERE source_id in (SELECT DISTINCT REGEXP_REPLACE(query_id,'(\\-\\d+\\-?\\*?\\(\\))','') AS source_id FROM  apidb.nextgenseq_align where sample = 'curated_long_polyA')
SQL


my $ssStmt = $dbh->prepare(<<SQL);
SELECT  REGEXP_REPLACE(ra.query_id,'(\\-\\d+\\-?\\*?\\(\\))','') as source_id, 
       CASE WHEN ra.strand = '+' THEN ra.start_a - 1 ELSE ra.end_a + 1 END as location,
       ra.strand as strand,
       ra.nextgenseq_align_id as feature_id
 FROM  apidb.nextgenseq_align ra, sres.externaldatabase d, sres.externaldatabaserelease rel
WHERE d.name = 'Tbrucei_RNASeq_Splice_Leader_And_Poly_A_Sites_George_Cross_RSRC'
 AND  rel.external_database_id = rel.external_database_id
 AND  ra.external_database_release_id = rel.external_database_release_id
 AND  ra.sample = 'curated_long_polyA'
SQL


my $updateQuery = "UPDATE apidb.nextgenseq_align
SET end_b = ?
WHERE nextgenseq_align_id = ?";

my $upStmt = $dbh->prepare($updateQuery);


# get Genes info
$geneStmt->execute();
my %genes;
my $ctGenes = 0;
while(my ($source_id,$na_sequence_id,$strand,$coding_start,$coding_end) = $geneStmt->fetchrow_array()){
  %genes->{$source_id} = {source_id => $source_id,
			  na_sequence_id => $na_sequence_id,
			  strand => $strand,
			  coding_start => $coding_start,
			  coding_end => $coding_end};
  $ctGenes++;
}
$geneStmt->finish();
print STDERR "Retrieved $ctGenes genes\n" if $verbose;

# get Poly A sites info
my $ct = 0;
$ssStmt->execute();
my @list;

while(my ($source_id,$location,$strand,$feature_id)= $ssStmt->fetchrow_array()){
    push(@list,{source_id=>$source_id,
		location=>$location,
		strand => $strand,
		feature_id => $feature_id});

  }
$ssStmt->finish();
print STDERR "Retrieved ",scalar(@list), " Poly A sites\n\n" if $verbose;


# work on the utr_distance
my $ct = 0;
my $ctRes = 0;
my %output;

my($src_id, $loc, $feature_id, $atg_loc, $utr_len, $key);
foreach my $site (@list){
  $ct++;
  print STDERR "Processing $ct\n" if ($verbose && $ct % 500 == 0);

  $feature_id = $site->{feature_id};
  my $id = $site->{source_id};
  my $geneStrand = $genes{$id}{strand};
  my $utr_len;


  if ($genes{$id}{strand} eq '+' ) {
    $utr_len = abs($site->{location} - $genes{$id}{coding_end});
  } elsif ($genes{$id}{strand} eq '-' ) {
    $utr_len = abs($site->{location} - $genes{$id}{coding_start});
  } else {
    print STDERR "NO utr_dist set for for feature_id: $feature_id\n";
  }

  if ($utr_len) {
    $ctRes++;
    print STDERR "RESULT: $feature_id,$utr_len\n" if ($verbose && $ct % 100 == 0);


    $upStmt->execute($utr_len,$feature_id);
    if (($ctRes % 100 == 0) && ($commit)){
      $dbh->do("commit");
    }
  }
}

if($commit){
  $dbh->do("commit");
} else {
  $dbh->do("rollback");
}

print STDERR "Processed $ctRes Poly A sites\n";

$db->logout();


