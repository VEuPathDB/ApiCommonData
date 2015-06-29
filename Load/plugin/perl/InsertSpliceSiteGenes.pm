package ApiCommonData::Load::Plugin::InsertSpliceSiteGenes;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use warnings;

use lib "$ENV{GUS_HOME}/lib/perl";

use GUS::PluginMgr::Plugin;
use GUS::Model::ApiDB::SpliceSiteGenes;




# ----------------------------------------------------------
# Load Arguments
# ----------------------------------------------------------

  my $argsDeclaration  =
    [
     stringArg({ name => 'sampleName',
		 descr => 'sample names in ApiDB.SpliceSiteFeature',
		 constraintFunc=> undef,
		 reqd  => 1,
		 isList => 0,
	       }),

     stringArg({ name => 'tuningTablePrefix',
		 descr => 'prefix of organism specific tuning table, example: P2_, 2 is the organism_id from apidb.organism',
		 constraintFunc=> undef,
		 reqd  => 0,
		 isList => 0,
	       }),
    ];


# ----------------------------------------------------------
# Documentation
# ----------------------------------------------------------

  my $description = <<DESCR;
DESCR

  my $purpose = <<PURPOSE;
PURPOSE

  my $purposeBrief = <<PURPOSEBRIEF;
Populate ApiDB.SpliceSiteGenes
PURPOSEBRIEF

  my $notes = <<NOTES;
NOTES

  my $tablesAffected = <<AFFECT;
ApiDB.OrganismProject
AFFECT

  my $tablesDependedOn = <<TABD;
TABD

  my $howToRestart = <<RESTART;
No restart provided. Undo and re-run.
RESTART

  my $failureCases = <<FAIL;
FAIL

  my $documentation = { purpose          => $purpose,
			purposeBrief     => $purposeBrief,
			tablesAffected   => $tablesAffected,
			tablesDependedOn => $tablesDependedOn,
			howToRestart     => $howToRestart,
			failureCases     => $failureCases,
			notes            => $notes
		      };


sub new {
  my ($class) = @_;
  my $self = {};
  bless($self, $class);

  $self->initialize ({ requiredDbVersion => 3.6,
			cvsRevision => '$Revision$',
			name => ref($self),
			argsDeclaration => $argsDeclaration,
			documentation => $documentation
		      });

  return $self;
}

sub run {
  my ($self) = @_;

  my $sampleName = $self->getArg('sampleName');

  my $tuningTablePrefix;

  $tuningTablePrefix = $self->getArg('tuningTablePrefix') if $self->getArg('tuningTablePrefix');

  my $database = $self->getDb();

  my $algInvocationId = $database->getDefaultAlgoInvoId();

  my $tempTableCreateHSql = "CREATE TABLE apidb.SSGCoor_$algInvocationId AS
  SELECT na_sequence_id, source_id, alpha, beta, gamma, delta, strand FROM (
  --CASE A:  1st gene on forward strand
   SELECT ga.na_sequence_id , ga.source_id, 0 as alpha, ga.coding_start as beta, ga.end_max as gamma,
    CASE WHEN (sub3.delta < sub4.delta) THEN sub3.delta ELSE sub4.delta END AS delta, ga.strand
   FROM apidbTuning.${tuningTablePrefix}geneAttributes ga,
  (select min(coding_start) as coding_start_min, na_sequence_id from apidbTuning.${tuningTablePrefix}geneAttributes
   where gene_type='protein coding'
   group by na_sequence_id)  sub,
  (select min(nxt.coding_start) as delta, ga.source_id
   from apidbTuning.${tuningTablePrefix}geneAttributes ga, apidbTuning.${tuningTablePrefix}geneAttributes nxt
   where ga.na_sequence_id = nxt.na_sequence_id
   and nxt.gene_type='protein coding'
   and nxt.coding_start > ga.coding_start  group by ga.source_id) sub3,
  (select min(nxt.coding_end) as delta, ga.source_id
   from apidbTuning.${tuningTablePrefix}geneAttributes ga, apidbTuning.${tuningTablePrefix}geneAttributes nxt
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
  FROM apidbTuning.${tuningTablePrefix}geneAttributes ga, 
   (select max(prev.coding_end) as alpha, ga.source_id
    from apidbTuning.${tuningTablePrefix}geneAttributes ga, apidbTuning.${tuningTablePrefix}geneAttributes prev
    where ga.na_sequence_id = prev.na_sequence_id
    and prev.gene_type='protein coding'
    and prev.coding_end < ga.coding_start  group by ga.source_id) sub1,
   (select max(prev.coding_start) as alpha, ga.source_id
    from apidbTuning.${tuningTablePrefix}geneAttributes ga, apidbTuning.${tuningTablePrefix}geneAttributes prev
    where ga.na_sequence_id = prev.na_sequence_id
    and prev.gene_type='protein coding'
    and prev.coding_start < ga.coding_start group by ga.source_id) sub2,
   (select min(nxt.coding_start) as delta, ga.source_id
    from apidbTuning.${tuningTablePrefix}geneAttributes ga, apidbTuning.${tuningTablePrefix}geneAttributes nxt
    where ga.na_sequence_id = nxt.na_sequence_id
    and nxt.gene_type='protein coding'
    and nxt.coding_start > ga.coding_start  group by ga.source_id) sub3,
   (select min(nxt.coding_end) as delta, ga.source_id
    from apidbTuning.${tuningTablePrefix}geneAttributes ga, apidbTuning.${tuningTablePrefix}geneAttributes nxt
    where ga.na_sequence_id = nxt.na_sequence_id
    and nxt.gene_type='protein coding'
    and nxt.coding_end > ga.coding_end group by ga.source_id) sub4
  WHERE ga.source_id = sub1.source_id  and ga.source_id = sub2.source_id
  AND ga.source_id = sub3.source_id  and ga.source_id = sub4.source_id
  AND ga.gene_type='protein coding' and ga.is_reversed=0
  UNION
  --CASE C:  last gene on reverse strand
  SELECT ga.na_sequence_id , ga.source_id, ga.coding_end as alpha, ga.coding_start as beta, sa.length as gamma,
   CASE WHEN (sub3.delta < sub4.delta) THEN sub3.delta ELSE sub4.delta END AS delta, ga.strand
  FROM apidbTuning.${tuningTablePrefix}geneAttributes ga, apidbTuning.${tuningTablePrefix}SequenceAttributes sa,
    (select max(end_max) as max_end_max, na_sequence_id from apidbTuning.${tuningTablePrefix}geneAttributes
     where gene_type='protein coding'
     group by na_sequence_id)  sub,
    (select max(nxt.coding_start) as delta, ga.source_id
     from apidbTuning.${tuningTablePrefix}geneAttributes ga, apidbTuning.${tuningTablePrefix}geneAttributes  nxt
     where ga.na_sequence_id = nxt.na_sequence_id
     and nxt.gene_type='protein coding'
     and nxt.coding_start < ga.coding_end  group by ga.source_id) sub3,
    (select max(nxt.coding_end) as delta, ga.source_id
     from apidbTuning.${tuningTablePrefix}geneAttributes ga, apidbTuning.${tuningTablePrefix}geneAttributes  nxt
     where ga.na_sequence_id = nxt.na_sequence_id
     and nxt.gene_type='protein coding'
     and nxt.coding_end < ga.coding_start group by ga.source_id) sub4
  WHERE ga.na_sequence_id = sub.na_sequence_id
  AND ga.source_id = sub3.source_id  and ga.source_id = sub4.source_id
  AND sa.na_sequence_id = ga.na_sequence_id
  AND ga.end_max = sub.max_end_max and ga.is_reversed=1
  UNION
  --CASE D: other genes on reverse strand
  SELECT ga.na_sequence_id , ga.source_id, ga.coding_end as alpha, ga.coding_start as beta,
  CASE WHEN (sub1.gamma < sub2.gamma) THEN sub1.gamma ELSE sub2.gamma END AS gamma,
  CASE WHEN (sub3.delta < sub4.delta) THEN sub3.delta ELSE sub4.delta END AS delta, ga.strand
  FROM apidbTuning.${tuningTablePrefix}geneAttributes ga,
    (select min(prev.coding_end) as gamma, ga.source_id
     from apidbTuning.${tuningTablePrefix}geneAttributes ga, apidbTuning.${tuningTablePrefix}geneAttributes  prev
     where ga.na_sequence_id = prev.na_sequence_id
     and prev.gene_type='protein coding'
     and prev.coding_end > ga.coding_end  group by ga.source_id) sub1,
    (select min(prev.coding_start) as gamma, ga.source_id
     from apidbTuning.${tuningTablePrefix}geneAttributes ga, apidbTuning.${tuningTablePrefix}geneAttributes  prev
     where ga.na_sequence_id = prev.na_sequence_id
     and prev.gene_type='protein coding'
     and prev.coding_start > ga.coding_start group by ga.source_id) sub2,
    (select max(nxt.coding_start) as delta, ga.source_id
     from apidbTuning.${tuningTablePrefix}geneAttributes ga, apidbTuning.${tuningTablePrefix}geneAttributes  nxt
     where ga.na_sequence_id = nxt.na_sequence_id
     and nxt.gene_type='protein coding'
     and nxt.coding_start < ga.coding_end  group by ga.source_id) sub3,
    (select max(nxt.coding_end) as delta, ga.source_id
     from apidbTuning.${tuningTablePrefix}geneAttributes ga, apidbTuning.${tuningTablePrefix}geneAttributes nxt
     where ga.na_sequence_id = nxt.na_sequence_id
     and nxt.gene_type='protein coding'
     and nxt.coding_end < ga.coding_start group by ga.source_id) sub4
  WHERE ga.source_id = sub1.source_id and ga.source_id = sub2.source_id
  AND ga.source_id = sub3.source_id and ga.source_id = sub4.source_id
  AND ga.gene_type='protein coding' and ga.is_reversed=1
  )
 WHERE na_sequence_id in 
  (SELECT distinct na_sequence_id FROM apidb.splicesitefeature where type = 'Splice Site' and sample_name='$sampleName')
 ORDER BY na_sequence_id, alpha";

  my $dbh = $self->getQueryHandle();

  my $tempTableCreateH = $dbh->prepare($tempTableCreateHSql);

  $tempTableCreateH->execute() or die $dbh->errstr;

  $tempTableCreateH->finish();

  my $sql ="select ssf.splice_site_feature_id, ssf.location, ssf.strand, ga.source_id, abs(ga.beta-ssf.location) as dist_to_cds,
  CASE WHEN (ssf.location>ga.beta) THEN 1 ELSE 0 END as within_cds,
  ssf.sample_name, ssf.count, ssf.count_per_million, ssf.avg_mismatches, ssf.is_unique,
  ssf.type, ssf.na_sequence_id, ssf.external_database_release_id
  from apidb.splicesitefeature ssf, apidb.SSGCoor_$algInvocationId ga
  where ga.na_sequence_id = ssf.na_sequence_id
  and ga.strand='forward'
  and ssf.strand ='+' and ssf.type='Splice Site'
  and ssf.location<= ga.gamma and ssf.location>= ga.alpha
  and ssf.sample_name='$sampleName'
  UNION
  select ssf.splice_site_feature_id, ssf.location, ssf.strand, ga.source_id, abs(ga.beta-ssf.location) as dist_to_cds,
  CASE WHEN (ssf.location<ga.beta) THEN 1 ELSE 0 END as within_cds,
  ssf.sample_name, ssf.count, ssf.count_per_million, ssf.avg_mismatches, ssf.is_unique,
  ssf.type, ssf.na_sequence_id, ssf.external_database_release_id
  from apidb.splicesitefeature ssf, apidb.SSGCoor_$algInvocationId ga
  where ga.na_sequence_id = ssf.na_sequence_id
  and ga.strand='reverse'
  and ssf.sample_name='$sampleName'
  and ssf.strand ='-' and ssf.type='Splice Site'
  and ssf.location<= ga.gamma and ssf.location>= ga.alpha";

  my $sth = $self->prepareAndExecute($sql);
  my $numRow=0;
  while (my @row = $sth->fetchrow_array()){ 
        my $spliceSiteGenes =  GUS::Model::ApiDB::SpliceSiteGenes->new({'splice_site_feature_id' => $row[0],
						    'location' => $row[1],
						    'strand' => $row[2],
                                                    'source_id' => $row[3],
						    'dist_to_cds' => $row[4],
						    'within_cds' => $row[5],	
						    'sample_name' => $row[6],
						    'count' => $row[7],
						    'count_per_million' => $row[8],
						    'avg_mismatches' => $row[9],
                                                    'is_unique' => $row[10],
						    'type' => $row[11],
						    'na_sequence_id' => $row[12],
						    'external_database_release_id' => $row[13],							    
						   });
   $spliceSiteGenes->submit() unless $spliceSiteGenes->retrieveFromDB();
   $numRow++;
    if ($numRow % 100 == 0){
      $self->log("$numRow rows added to apidb.SpliceSiteGenes.");
      $self->undefPointerCache();
    }
  }
  my $tempTableDropH = $dbh->prepare("DROP TABLE apidb.SSGCoor_$algInvocationId");
  $tempTableDropH->execute() or die $dbh->errstr;
  $tempTableDropH->finish();
}





sub undoTables {
  return qw(ApiDB.SpliceSiteGenes
           );
}
