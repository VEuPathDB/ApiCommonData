package ApiCommonData::Load::Plugin::InsertExtNaSeqFromRadShortOligo;
@ISA = qw( GUS::PluginMgr::Plugin);

use strict;

use GUS::PluginMgr::Plugin;
use lib "$ENV{GUS_HOME}/lib/perl";
use GUS::Model::DoTS::ExternalNASequence;
use GUS::Model::RAD::ElementNASequence;


my $purposeBrief = <<PURPOSEBRIEF;
Link oligos stored in RAD.ShortOligo to DoTS.ExternalNaSequence by inserting them there and linking via RAD.ElementNaSequence. Retain the external_database_release_id.
PURPOSEBRIEF

my $purpose = <<PLUGIN_PURPOSE;
Link oligos stored in RAD.ShortOligo to DoTS.ExternalNaSequence by inserting
them there and linking via RAD.ElementNaSequence. Retain the external_database_release_id.
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

  my $arrayDesignName = $self->getArg('arrayDesignName');

  my $sql = "
SELECT sequence, element_id, source_id
FROM RAD.ShortOligo o, RAD.ShortOligoFamily of, RAD.ArrayDesign a
WHERE a.name = '$arrayDesignName'
AND of.array_design_id = a.array_design_id
AND o.composite_element_id = of.composite_element_id
ORDER BY source_id
";

  my $stmt = $self->prepareAndExecute($sql);
  my $sourceIdHash = {};
  while (my ($seq, $elementId, $sourceId) = $stmt->fetchrow_array()) {
    push(@{$sourceIdHash->{$sourceId}}, [$seq, $elementId]);
  }

  if (scalar(keys %{$sourceIdHash}) == 0) {
    $self->error("Didn't find any oligos for arrayDesignName=$arrayDesignName");
  }

  my $count = 0;
  foreach my $sourceId (keys %{$sourceIdHash}) {
    my @sortedOligos =sort {$a->[0] cmp $b->[0]} @{$sourceIdHash->{$sourceId}};
    my $o = 0;
    foreach my $oligo (@sortedOligos) {
      if ($count++ % 5000 == 0) {
	$self->undefPointerCache();
	$self->log("processing oligo number $count");
      }
      my $naSeq = GUS::Model::DoTS::ExternalNASequence->
	new({sequence => $oligo->[0],
	     source_id => "${sourceId}_$o",
	     external_database_release_id =>$extDbRlsId});

      my $elementNaSeq = GUS::Model::RAD::ElementNASequence->
	new({element_id=>$oligo->[1]});
      $naSeq->addChild($elementNaSeq);
      $naSeq->submit();
    }
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
