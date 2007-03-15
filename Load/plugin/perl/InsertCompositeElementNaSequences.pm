package ApiCommonData::Load::Plugin::InsertCompositeElementNaSequences;
@ISA = qw( GUS::PluginMgr::Plugin);

use strict 'vars';

use GUS::PluginMgr::Plugin;
use lib "$ENV{GUS_HOME}/lib/perl";
use ApiCommonData::Load::Util;
use GUS::Model::RAD::CompositeElementNASequence;


my $purposeBrief = <<PURPOSEBRIEF;
Read the source_id from the RAD.ShortOligoFamily table, find the corresponding gene (using ApiDb.GeneAlias), and link the ShortOligoFamily to the gene's transcript's DoTS.SplicedNaSequence, using RAD.CompositeElementNaSequence
PURPOSEBRIEF

my $purpose = <<PLUGIN_PURPOSE;
Read the source_id from the RAD.ShortOligoFamily table, find the corresponding gene (using ApiDb.GeneAlias), and link the ShortOligoFamily to the gene's transcript's DoTS.SplicedNaSequence, using RAD.CompositeElementNaSequence
PLUGIN_PURPOSE

my $tablesAffected =
        [['RAS.CompositeElementNaSequence', '']];


my $tablesDependedOn = [['RAD.ShortOligoFamily', ''],
		       ['ApiDb.GeneAlias', ''],
		       ['DoTS.GeneFeature', ''],
		       ['DoTS.Transcript', ''],
		       ['DoTS.SplicedNaSequence', ''],
		       ];


my $howToRestart = <<PLUGIN_RESTART;
There is currently no restart method.
PLUGIN_RESTART

my $failureCases = <<PLUGIN_FAILURE_CASES;
There are no known failure cases.
PLUGIN_FAILURE_CASES

my $notes = <<PLUGIN_NOTES;

PLUGIN_NOTES

my $documentation = { purpose=>$purpose,
		      purposeBrief=>$purposeBrief,
		      tablesAffected=>$tablesAffected,
		      tablesDependedOn=>$tablesDependedOn,
		      howToRestart=>$howToRestart,
		      failureCases=>$failureCases,
		      notes=>$notes
		    };


my $argsDeclaration = 
  [
   stringArg({name => 'arrayDesignName',
	      descr => 'Name of array design as found in RAD.ArrayDesign.name',
	      reqd => 1,
	      constraintFunc => undef,
	      isList => 0,
	     }),
  ];


sub new {
    my ($class) = @_;
    my $self = {};
    bless($self,$class);

    $self->initialize({requiredDbVersion => 3.5,
		       cvsRevision => '$Revision: 15062 $', # cvs fills this in!
		       name => ref($self),
		       argsDeclaration => $argsDeclaration,
		       documentation => $documentation
		      });

    return $self;
}

sub run {
  my ($self) = @_;

  my $arrayDesignName = $self->getArg('arrayDesignName');

  # first check that there are no null source_ids
  my $sql = "
SELECT count(element_id)
FROM RAD.ShortOligoFamily sof, RAD.ArrayDesign a
WHERE a.name = '$arrayDesignName'
AND sof.array_design_id = a.array_design_id
AND sof.source_id is null
";

  my $stmt = $self->prepareAndExecute($sql);

  my ($nulls) = $stmt->fetchrow_array();
  $self->error("found $nulls oligo families w/ null source_id") if $nulls;

  my $sql = "
SELECT source_id, composite_element_id
FROM RAD.ShortOligoFamily sof, RAD.ArrayDesign a
WHERE a.name = '$arrayDesignName'
AND sof.array_design_id = a.array_design_id
";

  my $stmt = $self->prepareAndExecute($sql);
  my $count = 0;
  while (my ($sourceId, $compositeElementId) = $stmt->fetchrow_array()) {
    if ($count++ % 1000 == 0) {
      $self->undefPointerCache();
      $self->log("processing oligo family number $count");
    }
    my $transcriptSequenceId =
      ApiCommonData::Load::Util::getTranscriptSequenceIdFromGeneSourceId($self,$sourceId);

    my $compositeElementNaSeq = GUS::Model::RAD::ElementNASequence->
      new({composite_element_id=>$compositeElementId,
	   na_sequence_id => $transcriptSequenceId});
    $compositeElementNaSeq->submit();
  }

  my $msg = "Inserted $count composite element na seqs";

  return $msg;

}

sub undoTables {
  my ($self) = @_;

  return ('RAD.CompositeElementNASequence',
	 );
}



1;
