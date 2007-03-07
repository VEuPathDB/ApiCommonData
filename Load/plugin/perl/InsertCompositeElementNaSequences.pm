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
   stringArg({name => 'extDbName',
	      descr => 'the external database name with which to find the oligo families in RAD.',
	      reqd => 1,
	      constraintFunc => undef,
	      isList => 0,
	     }),
   stringArg({name => 'extDbReleaseNumber',
	      descr => 'the version of the external database with which to find the oligo families in RAD',
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

  my $extDbRlsId = $self->getExtDbRlsId($self->getArg('extDbName'),
					$self->getArg('extDbRlsVer'));

  die "Couldn't find external_database_release_id" unless $extDbRlsId;

  my $sql = "SELECT name,source_id, composite_element_id FROM RAD.ShortOligoFamily WHERE external_database_release_id = $extDbRlsId";

  my $stmt = $self->prepareAndExecute($sql);
  my $count = 0;
  while (my ($name, $sourceId, $compositeElementId) = $stmt->fetchrow_array()) {
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
