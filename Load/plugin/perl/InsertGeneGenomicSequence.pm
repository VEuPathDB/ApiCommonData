package ApiCommonData::Load::Plugin::InsertGeneGenomicSequence;

@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use warnings;

use GUS::PluginMgr::Plugin;
use FileHandle;

use GUS::Supported::Util;

use GUS::Model::DoTS::ExternalNASequence;
use GUS::Model::ApiDB::GeneGenomicSequence_Split;

my $argsDeclaration =
  [
      stringArg({name => 'dbRlsIds',
              descr => 'genome external database release id',
              reqd => 1,
              isList => 0,
              constraintFunc => undef,
             }),
];

my $purpose = <<PURPOSE;
The plugin populates a new table called ApiDB.GeneGenomicSequence_Split to speed up live site performance.It pre-computes values made now by the slow GeneModel wdk table query, which is slowing down the gene pages. 

The new table includes:
- source_id
- gene_genomic_sequence, which is the full length of the genomic sequence for the gene (reversed as needed), possibly including some flanking sequence. flanking sequence and introns would be lower-cased, exons would be upper-cased.
- start_min

PURPOSE

my $purposeBrief = <<PURPOSE_BRIEF;
The plugin populates a new table called ApiDB.GeneGenomicSequence_Split to speed up live site performance.It pre-computes values made now by the slow GeneModel wdk table query, which is slowing down the gene pages.
PURPOSE_BRIEF

my $notes = <<NOTES;
NOTES

my $tablesAffected = <<TABLES_AFFECTED;
TABLES_AFFECTED

my $tablesDependedOn = <<TABLES_DEPENDED_ON;
TABLES_DEPENDED_ON

my $howToRestart = <<RESTART;
No Restart utilities for this plugin.
RESTART

my $failureCases = <<FAIL_CASES;
FAIL_CASES

my $documentation = { purpose          => $purpose,
		      purposeBrief     => $purposeBrief,
		      notes            => $notes,
		      tablesAffected   => $tablesAffected,
		      tablesDependedOn => $tablesDependedOn,
		      howToRestart     => $howToRestart,
		      failureCases     => $failureCases };

# ----------------------------------------------------------------------

sub new {
  my ($class) = @_;
  my $self = {};
  bless($self,$class);

  $self->initialize({ requiredDbVersion => 3.6,
		      cvsRevision       => '$Revision$',
		      name              => ref($self),
		      argsDeclaration   => $argsDeclaration,
		      documentation     => $documentation});
  return $self;
}


sub run {
  my ($self) = @_;

  my $dbRlsIds=  $self->getArg('dbRlsIds');
  my $dbh = $self->getQueryHandle();
  my $sql = "select gf.source_id, type,
             case
              when type = 'CDS' and gl.is_reversed = 0
               then upper(substr(s.sequence, gm.start_min, (gm.end_max - gm.start_min) + 1))
              when type = 'CDS' and gl.is_reversed = 1
               then upper(apidb.reverse_complement_clob(substr(s.sequence, gm.start_min, (gm.end_max - gm.start_min) + 1)))
              when (type = 'intron' OR type = 'UTR') and gl.is_reversed = 0
               then lower(substr(s.sequence, gm.start_min, (gm.end_max - gm.start_min) + 1))
              when (type = 'intron' OR type = 'UTR') and gl.is_reversed = 1 and gm.end_max >= gm.start_min
               then lower(apidb.reverse_complement_clob(substr(s.sequence, gm.start_min, (gm.end_max - gm.start_min) + 1)))
             end as sequence,
             case 
	      when gl.is_reversed = 1 then -1 * gm.start_min 
              else gm.start_min 
             end as start_min
             from dots.GeneFeature gf, dots.nalocation gl, dots.NaSequence s,
             (select 'UTR' as type, ef.parent_id as na_feature_id, l.start_min, l.end_max
              from dots.exonfeature ef, dots.nalocation l
              where ef.na_feature_id = l.na_feature_id
              and (ef.coding_end is null
                 or ef.coding_start is null)
              UNION
              select 'UTR' as type, ef.parent_id as na_feature_id, l.start_min, least(ef.coding_start, ef.coding_end) - 1 as end_max
              from dots.exonfeature ef, dots.nalocation l
              where ef.na_feature_id = l.na_feature_id
              and greatest(ef.coding_end, ef.coding_start) = l.end_max
              and least(ef.coding_end, ef.coding_start) != l.start_min
              UNION
              select 'UTR' as type, ef.parent_id as na_feature_id, greatest(ef.coding_start, ef.coding_end) + 1 as start_min, l.end_max
              from dots.exonfeature ef, dots.nalocation l
              where ef.na_feature_id = l.na_feature_id
              and least(ef.coding_end, ef.coding_start) = l.start_min
              and greatest(ef.coding_end, ef.coding_start) != l.end_max
              UNION
              select 'CDS' as type, ef.parent_id as na_feature_id,  least(ef.coding_start, ef.coding_end) as start_min, greatest(ef.coding_start, ef.coding_end) as end_max
              from dots.ExonFeature ef, dots.nalocation el
              where ef.na_feature_id = el.na_feature_id
              and ef.coding_start >0
              union
              select 'intron' as type, left.parent_id as na_feature_id, leftLoc.end_max + 1  as start_min, rightLoc.start_min - 1 as end_max
              from dots.ExonFeature left, dots.nalocation leftLoc,  dots.ExonFeature right, dots.nalocation rightLoc
              where left.parent_id = right.parent_id
              and (left.order_number = right.order_number - 1 or left.order_number = right.order_number + 1)
              and leftLoc.start_min < rightLoc.start_min
              and left.na_feature_id = leftLoc.na_feature_id
              and right.na_feature_id = rightLoc.na_feature_id  ) gm
          where gm.na_feature_id = gf.na_feature_id
          and s.na_sequence_id = gf.na_sequence_id
          and gf.na_feature_id = gl.na_feature_id
          and gf.external_database_release_id in ($dbRlsIds)";


  my $sh = $dbh->prepare($sql);
  $sh->execute();

  while(my ($source_id, $type, $gene_genomic_sequence, $start_min) = $sh->fetchrow_array()) {
     my $profile = GUS::Model::ApiDB::GeneGenomicSequence_Split->
	      new({source_id => $source_id,
		   gene_genomic_sequence => $gene_genomic_sequence,
		   start_min => $start_min,
                   feature_type => $type,
		   });
	  $profile->submit();
          $self->undefPointerCache();
  }

  $self->log("Done inserted sequences");
}

sub undoTables {
  my ($self) = @_;

  return ('ApiDB.GeneGenomicSequence_Split',
	 );
}

1;

