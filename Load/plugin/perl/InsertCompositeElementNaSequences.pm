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
	      reqd => 0,
	      constraintFunc => undef,
	      isList => 0,
	     }),

   booleanArg({name => 'tolerateUnmappables',
	      descr => 'Do not fail on composite elements that do not correspond to a gene',
	      reqd => 0,
	      default => 0,
	      isList => 0,
	     }),

   fileArg({name => 'simpleMapFile',
            descr => '2 column tab delimeted file.  The na_sequence_id should be for the transcript (spliced na sequence)',
            constraintFunc=> undef,
            reqd  => 0,
            isList => 0,
            mustExist => 1,
            format => 'composite_element_id      na_sequence_id'
           }),
  ];


sub new {
    my ($class) = @_;
    my $self = {};
    bless($self,$class);

    $self->initialize({requiredDbVersion => 3.5,
		       cvsRevision => '$Revision$', # cvs fills this in!
		       name => ref($self),
		       argsDeclaration => $argsDeclaration,
		       documentation => $documentation
		      });

    return $self;
}

sub run {
  my ($self) = @_;

  my $count = 0;
  my $unmapped =0;

  if(my $fn = $self->getArg('simpleMapFile')) {
    $count = $self->doFromFile($fn);
  }
  elsif(my $arrayDesignName = $self->getArg('arrayDesignName')) {
    ($count, $unmapped) = $self->doFromDb($arrayDesignName);
  }
  else {
    $self->userError("Plugin Requires Either a simpleMapFile OR an arrayDesignName argument");
  }

  return("Inserted $count composite element na seqs.  $unmapped composite elements were not mappable to a transcript");
}

sub doFromFile {
  my ($self, $fn) = @_;

  my $count;

  open(FILE, $fn) or die "Cannot open file $fn for reading:$!";

  while(<FILE>) {
    chomp;
    $count++;

    if ($count % 1000 == 0) {
      $self->undefPointerCache();
      $self->log("processing oligo family number $count");
    }

    my ($compositeElementId, $transcriptSequenceId) = split(/\t/, $_);

    my $compositeElementNaSeq = GUS::Model::RAD::CompositeElementNASequence->
      new({composite_element_id=>$compositeElementId,
           na_sequence_id => $transcriptSequenceId});
    $compositeElementNaSeq->submit();
  }
  close FILE;

  return $count;
}

sub doFromDb {
  my ($self, $arrayDesignName) = @_;

  my $count = 0;
  my $unmapped = 0;

  my $sql = "
SELECT sof.source_id, composite_element_id
FROM RAD.ShortOligoFamily sof, RAD.ArrayDesign a
WHERE a.name = '$arrayDesignName'
AND sof.array_design_id = a.array_design_id
AND sof.source_id is not null
";

  my $stmt = $self->prepareAndExecute($sql);
  while (my ($geneSourceId, $compositeElementId) = $stmt->fetchrow_array()) {
    if ($count % 1000 == 0) {
      $self->undefPointerCache();
      $self->log("processing oligo family number $count ($unmapped unmappable so far)");
    }
    $count++;
    my $transcriptSequenceId =
      ApiCommonData::Load::Util::getTranscriptSequenceIdFromGeneSourceId($self, $geneSourceId);

    if (!$transcriptSequenceId) {
      my $msg = "no transcript seq found for gene '$geneSourceId'";

      $self->error($msg)
        unless $self->getArg('tolerateUnmappables');

      $self->log("WARN: $msg");
      $unmapped++;
      next;
    }
    my $compositeElementNaSeq = GUS::Model::RAD::CompositeElementNASequence->
      new({composite_element_id=>$compositeElementId,
           na_sequence_id => $transcriptSequenceId});
    $compositeElementNaSeq->submit();
  }
  $stmt->finish();

  return($count, $unmapped);
}


sub undoTables {
  my ($self) = @_;

  return ('RAD.CompositeElementNASequence',
	 );
}



1;
