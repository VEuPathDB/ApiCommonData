#!/usr/bin/perl
#vvvvvvvvvvvvvvvvvvvvvvvvv GUS4_STATUS vvvvvvvvvvvvvvvvvvvvvvvvv
  # GUS4_STATUS | SRes.OntologyTerm              | auto   | absent
  # GUS4_STATUS | SRes.SequenceOntology          | auto   | broken
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

## to populate apidb.polyAGenes table

use strict;
use Getopt::Long;
use lib "$ENV{GUS_HOME}/lib/perl";
use GUS::ObjRelP::DbiDatabase;
use GUS::Supported::GusConfig;

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

# make the temp table
my $tempTableCreateH = $dbh->prepare(<<SQL);
  CREATE TABLE apidb.SpliceSiteGeneCoordinates AS
  SELECT na_sequence_id, source_id, alpha, beta, gamma, delta, strand FROM (
  --CASE A:  1st gene on forward strand
   SELECT ga.na_sequence_id , ga.source_id, 0 as alpha, ga.coding_start as beta, ga.end_max as gamma,
    CASE WHEN (sub3.delta < sub4.delta) THEN sub3.delta ELSE sub4.delta END AS delta, ga.strand
   FROM webready.GeneAttributes ga,
  (select min(coding_start) as coding_start_min, na_sequence_id from webready.GeneAttributes
   where gene_type='protein coding'
   group by na_sequence_id)  sub,
  (select min(nxt.coding_start) as delta, ga.source_id
   from webready.GeneAttributes ga, webready.GeneAttributes nxt
   where ga.na_sequence_id = nxt.na_sequence_id
   and nxt.gene_type='protein coding'
   and nxt.coding_start > ga.coding_start  group by ga.source_id) sub3,
  (select min(nxt.coding_end) as delta, ga.source_id
   from webready.GeneAttributes ga, webready.GeneAttributes nxt
   where ga.na_sequence_id = nxt.na_sequence_id
   and nxt.gene_type='protein coding' 
   and nxt.coding_end > ga.coding_end group by ga.source_id) sub4
 WHERE ga.na_sequence_id = sub.na_sequence_id
 AND ga.source_id = sub3.source_id and ga.source_id = sub4.source_id
 AND ga.coding_start = sub.coding_start_min
 AND ga.gene_type='protein coding' and is_reversed=0
UNION
-- CASE B: other genes on forward strand
 SELECT ga.na_sequence_id , ga.source_id,
  CASE WHEN (sub1.alpha > sub2.alpha) THEN sub1.alpha ELSE sub2.alpha END AS alpha,
  ga.coding_start as beta, ga.end_max as gamma,
  CASE WHEN (sub3.delta < sub4.delta) THEN sub3.delta ELSE sub4.delta END AS delta, ga.strand
 FROM webready.GeneAttributes ga, 
   (select max(prev.coding_end) as alpha, ga.source_id
    from webready.GeneAttributes ga, webready.GeneAttributes prev
    where ga.na_sequence_id = prev.na_sequence_id
    and prev.gene_type='protein coding'
    and prev.coding_end < ga.coding_start  group by ga.source_id) sub1,
   (select max(prev.coding_start) as alpha, ga.source_id
    from webready.GeneAttributes ga, webready.GeneAttributes prev
    where ga.na_sequence_id = prev.na_sequence_id
    and prev.gene_type='protein coding'
    and prev.coding_start < ga.coding_start group by ga.source_id) sub2,
   (select min(nxt.coding_start) as delta, ga.source_id
    from webready.GeneAttributes ga, webready.GeneAttributes nxt
    where ga.na_sequence_id = nxt.na_sequence_id
    and nxt.gene_type='protein coding'
    and nxt.coding_start > ga.coding_start  group by ga.source_id) sub3,
   (select min(nxt.coding_end) as delta, ga.source_id
    from webready.GeneAttributes ga, webready.GeneAttributes nxt
    where ga.na_sequence_id = nxt.na_sequence_id
    and nxt.gene_type='protein coding'
    and nxt.coding_end > ga.coding_end group by ga.source_id) sub4
 WHERE ga.source_id = sub1.source_id  and ga.source_id = sub2.source_id
 AND ga.source_id = sub3.source_id  and ga.source_id = sub4.source_id
 AND ga.gene_type='protein coding' and ga.is_reversed=0
UNION
--CASE C:  last gene on reverse strand
 SELECT ga.na_sequence_id , ga.source_id, ga.start_min as alpha, ga.coding_start as beta, sa.length as gamma,
  CASE WHEN (sub3.delta < sub4.delta) THEN sub3.delta ELSE sub4.delta END AS delta, ga.strand
 FROM webready.GeneAttributes ga, webready.GenomicSeqAttributes sa,
    (select max(end_max) as max_end_max, na_sequence_id from webready.GeneAttributes
     where gene_type='protein coding'
     group by na_sequence_id)  sub,
    (select max(nxt.coding_start) as delta, ga.source_id
     from webready.GeneAttributes ga, webready.GeneAttributes  nxt
     where ga.na_sequence_id = nxt.na_sequence_id
     and nxt.gene_type='protein coding'
     and nxt.coding_start < ga.coding_end  group by ga.source_id) sub3,
    (select max(nxt.coding_end) as delta, ga.source_id
     from webready.GeneAttributes ga, webready.GeneAttributes  nxt
     where ga.na_sequence_id = nxt.na_sequence_id
     and nxt.gene_type='protein coding'
     and nxt.coding_end < ga.coding_start group by ga.source_id) sub4
  WHERE ga.na_sequence_id = sub.na_sequence_id
  AND ga.source_id = sub3.source_id  and ga.source_id = sub4.source_id
  AND sa.na_sequence_id = ga.na_sequence_id
  AND ga.end_max = sub.max_end_max and ga.is_reversed=1
UNION
--CASE D: other genes on reverse strand
 SELECT ga.na_sequence_id , ga.source_id, ga.start_min as alpha, ga.coding_start as beta,
  CASE WHEN (sub1.gamma < sub2.gamma) THEN sub1.gamma ELSE sub2.gamma END AS gamma,
  CASE WHEN (sub3.delta < sub4.delta) THEN sub3.delta ELSE sub4.delta END AS delta, ga.strand
 FROM webready.GeneAttributes ga,
    (select min(prev.coding_end) as gamma, ga.source_id
     from webready.GeneAttributes ga, webready.GeneAttributes  prev
     where ga.na_sequence_id = prev.na_sequence_id
     and prev.gene_type='protein coding'
     and prev.coding_end > ga.coding_end  group by ga.source_id) sub1,
    (select min(prev.coding_start) as gamma, ga.source_id
     from webready.GeneAttributes ga, webready.GeneAttributes  prev
     where ga.na_sequence_id = prev.na_sequence_id
     and prev.gene_type='protein coding'
     and prev.coding_start > ga.coding_start group by ga.source_id) sub2,
    (select max(nxt.coding_start) as delta, ga.source_id
     from webready.GeneAttributes ga, webready.GeneAttributes  nxt
     where ga.na_sequence_id = nxt.na_sequence_id
     and nxt.gene_type='protein coding'
     and nxt.coding_start < ga.coding_end  group by ga.source_id) sub3,
    (select max(nxt.coding_end) as delta, ga.source_id
     from webready.GeneAttributes ga, webready.GeneAttributes nxt
     where ga.na_sequence_id = nxt.na_sequence_id
     and nxt.gene_type='protein coding'
     and nxt.coding_end < ga.coding_start group by ga.source_id) sub4
 WHERE ga.source_id = sub1.source_id and ga.source_id = sub2.source_id
 AND ga.source_id = sub3.source_id and ga.source_id = sub4.source_id
 AND ga.gene_type='protein coding' and ga.is_reversed=1
 )
WHERE na_sequence_id in 
 (SELECT distinct na_sequence_id FROM apidb.splicesitefeature where type = 'Poly A')
ORDER BY na_sequence_id, alpha
SQL

print STDERR "Make temp table\n" if $verbose;
$tempTableCreateH->execute() or die $dbh->errstr;



my $insertH = $dbh->prepare(<<SQL);
 INSERT INTO apidb.PolyAGenes
 (splice_site_feature_id, location, strand, source_id, dist_to_cds, within_cds,
  sample_name, count, count_per_million, avg_mismatches, is_unique,
  type, na_sequence_id, external_database_release_id)
 SELECT * FROM (
select ssf.splice_site_feature_id, ssf.location, ssf.strand, ga.source_id, abs(ga.gamma-ssf.location) as dist_to_cds,
CASE WHEN (ssf.location<ga.gamma) THEN 1 ELSE 0 END as within_cds,
ssf.sample_name, ssf.count, ssf.count_per_million, ssf.avg_mismatches, ssf.is_unique,
ssf.type, ssf.na_sequence_id, ssf.external_database_release_id
from apidb.splicesitefeature ssf, apidb.SpliceSiteGeneCoordinates ga
where ga.na_sequence_id = ssf.na_sequence_id
and ga.strand='forward'
and ssf.strand ='-' and ssf.type = 'Poly A'
and ssf.location<= ga.delta and ssf.location>= ga.beta
UNION
select ssf.splice_site_feature_id, ssf.location, ssf.strand, ga.source_id, abs(ga.alpha-ssf.location) as dist_to_cds,
CASE WHEN (ssf.location>ga.alpha) THEN 1 ELSE 0 END as within_cds,
ssf.sample_name, ssf.count, ssf.count_per_million, ssf.avg_mismatches, ssf.is_unique,
ssf.type, ssf.na_sequence_id, ssf.external_database_release_id
from apidb.splicesitefeature ssf, apidb.SpliceSiteGeneCoordinates ga
where ga.na_sequence_id = ssf.na_sequence_id
and ga.strand='reverse'
and ssf.strand ='+' and ssf.type = 'Poly A'
and ssf.location>= ga.delta and ssf.location<= ga.beta
) order by na_sequence_id, location
SQL


print STDERR "Create Poly A Genes table\n" if $verbose;
$insertH->execute() or die $dbh->errstr;
$insertH->finish();


# drop the temp table
my $tempTableDropH = $dbh->prepare(<<SQL);
  DROP TABLE apidb.SpliceSiteGeneCoordinates
SQL

print STDERR "Drop temp table\n" if $verbose;
$tempTableDropH->execute();
$tempTableDropH->finish();


#
my $updateH = $dbh->prepare(<<SQL);
UPDATE apidb.PolyAGenes SET is_dominant=1, percent_fraction=100, diff_to_next=100
WHERE splice_site_feature_id in
 (SELECT splice_site_feature_id
  FROM apidb.PolyAGenes ssg,
      (SELECT max(count_per_million) as max_max, sample_name, source_id
       FROM apidb.PolyAGenes
       GROUP BY source_id, sample_name) x
  WHERE ssg.count_per_million=x.max_max
  AND ssg.sample_name = x.sample_name
  AND ssg.source_id =x.source_id
  GROUP BY ssg.source_id, ssg.sample_name,x.max_max,splice_site_feature_id
 )
SQL

print STDERR "First update for is_dominant, etc \n" if $verbose;
$updateH->execute() or die $dbh->errstr();
if($commit){
  $dbh->do("commit");
}else{
  $dbh->do("rollback");
}


#
$updateH = $dbh->prepare(<<SQL);
UPDATE apidb.PolyAGenes SET is_dominant=null, percent_fraction=null, diff_to_next=null
WHERE splice_site_feature_id in
 (SELECT x.splice_site_feature_id
  from apidb.PolyAGenes x, apidb.PolyAGenes y
  where x.sample_name = y.sample_name
  and x.source_id = y.source_id
  and not x.location = y.location
  and x.is_dominant=1 and y.is_dominant =1)
SQL

print STDERR "Second update for is_dominant, etc \n" if $verbose;
$updateH->execute() or die $dbh->errstr();
if($commit){
  $dbh->do("commit");
}else{
  $dbh->do("rollback");
}
$updateH->finish();


# fix  percent_diff_to_next_next for cases when there is another (lower count) splice site
my $sql = <<SQL;
SELECT y.splice_site_feature_id,
round( ( (x.max_max) /z.mySum *100), 2) as percent_fraction,
round( ( (x.max_max - max(ssg.count_per_million)) /z.mySum *100), 2) as diff_to_next
FROM apidb.PolyAGenes ssg, apidb.PolyAGenes y,
 (SELECT max(count_per_million) as max_max, sample_name, source_id
  FROM apidb.PolyAGenes
  WHERE is_dominant=1 
  GROUP BY source_id, sample_name) x,
 (SELECT sum(count_per_million) as mySum, sample_name, source_id from apidb.PolyAGenes x
  GROUP BY x.sample_name,x.source_id) z
WHERE ssg.count_per_million < x.max_max
AND ssg.sample_name = x.sample_name
AND ssg.source_id = x.source_id
AND ssg.sample_name = z.sample_name
AND ssg.source_id = z.source_id
AND y.sample_name = ssg.sample_name and y.source_id = ssg.source_id and y.count_per_million = x.max_max
GROUP BY ssg.source_id, ssg.sample_name,x.max_max,y.splice_site_feature_id,y.sample_name, z.mySum
SQL

my $queryHandle = $dbh->prepare($sql) or die $dbh->errstr;
$queryHandle->execute() or die $dbh->errstr;

$sql = <<SQL;
UPDATE apidb.PolyAGenes
   SET percent_fraction=?, diff_to_next = ?
 WHERE splice_site_feature_id = ?
SQL
print STDERR "Update percent_fraction and diff_to_next columns\n" if $verbose;

my $updateHandle = $dbh->prepare($sql);
while (my ($splice_site_na_feat_id, $frac, $diff) = $queryHandle->fetchrow_array()) {

  if ($splice_site_na_feat_id) {
    $updateHandle->execute($frac, $diff, $splice_site_na_feat_id) or die $dbh->errstr;

    if($commit){
      $dbh->do("commit");
    }else{
      $dbh->do("rollback");
    }
  }
}
$updateHandle->finish();
$queryHandle->finish();
