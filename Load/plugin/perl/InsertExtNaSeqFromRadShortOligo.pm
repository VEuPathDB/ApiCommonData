package ApiCommonData::Load::Plugin::InsertExtNaSeqFromRadShortOligo;
@ISA = qw( GUS::PluginMgr::Plugin);

use strict;

use GUS::PluginMgr::Plugin;
use lib "$ENV{GUS_HOME}/lib/perl";
use GUS::Model::DoTS::ExternalNASequence;
use GUS::Model::RAD::ElementNASequence;
use Data::Dumper;


my $purposeBrief = <<PURPOSEBRIEF;
Link oligos stored in RAD.ShortOligo to DoTS.ExternalNaSequence by inserting them there and linking via RAD.ElementNaSequence. Retain the external_database_release_id.
PURPOSEBRIEF

my $purpose = <<PLUGIN_PURPOSE;
Link oligos stored in RAD.ShortOligo to DoTS.ExternalNaSequence by inserting
them there and linking via RAD.ElementNaSequence. 
PLUGIN_PURPOSE

my $tablesAffected =
	[['DoTS.ExternalNaSequence', ''],
        ['RAS.ElementNaSequence', '']];


my $tablesDependedOn = [['RAD.ShortOligo', '']];


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
	      descr => 'the external database name to tag the seq with.',
	      reqd => 1,
	      constraintFunc => undef,
	      isList => 0,
	     }),
   stringArg({name => 'extDbRlsVer',
	      descr => 'the version of the external database to tag the seq with.',
	      reqd => 1,
	      constraintFunc => undef,
	      isList => 0,
	     }),
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
		       cvsRevision => '$Revision$', # cvs fills this in!
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

  my $arrayDesignName = $self->getArg('arrayDesignName');

  # first check that there are no null source_ids
  my $sql = "
SELECT count(composite_element_id)
FROM RAD.ShortOligoFamily sof, RAD.ArrayDesign a
WHERE a.name = '$arrayDesignName'
AND sof.array_design_id = a.array_design_id
AND sof.source_id is null
";

  my $stmt = $self->prepareAndExecute($sql);

  my ($nulls) = $stmt->fetchrow_array();
  $self->error("found $nulls oligo families w/ null source_id") if $nulls;

  $sql = "
SELECT sequence, element_id, sof.source_id
FROM RAD.ShortOligo so, RAD.ShortOligoFamily sof, RAD.ArrayDesign a
WHERE a.name = '$arrayDesignName'
AND sof.array_design_id = a.array_design_id
AND so.composite_element_id = sof.composite_element_id
ORDER BY sof.source_id
";

  my $stmt = $self->prepareAndExecute($sql);
  my $sourceIdHash = {};
  while (my ($seq, $elementId, $sourceId) = $stmt->fetchrow_array()) {
    push(@{$sourceIdHash->{$sourceId}}, [$seq, $elementId]);
  }

  if (scalar(keys %{$sourceIdHash}) == 0) {
    $self->error("Didn't find any oligos for arrayDesignName=$arrayDesignName");
  }

  my $count = 1;
  foreach my $sourceId (keys %{$sourceIdHash}) {
    my @sortedOligos =sort {$a->[0] cmp $b->[0]} @{$sourceIdHash->{$sourceId}};
    my $o = 0;
    foreach my $oligo (@sortedOligos) {
      $o++;
      if ($count % 5000 == 0) {
	$self->undefPointerCache();
	$self->log("processing oligo number $count");
      }
      $count++;
      my $naSeq = GUS::Model::DoTS::ExternalNASequence->
	new({sequence => $oligo->[0],
	     sequence_version => "1",
	     source_id => "${sourceId}_$o",
	     external_database_release_id =>$extDbRlsId});

      my $elementNaSeq = GUS::Model::RAD::ElementNASequence->
	new({element_id=>$oligo->[1]});
      $naSeq->addChild($elementNaSeq);
      $naSeq->submit();
    }
      exit();
  }

  my $msg = "Inserted $count na seqs";

  return $msg;

}

sub undoTables {
  my ($self) = @_;

  return ('DoTS.ExternalNASequence',
	  'RAD.ElementNASequence',
	 );
}



1;
