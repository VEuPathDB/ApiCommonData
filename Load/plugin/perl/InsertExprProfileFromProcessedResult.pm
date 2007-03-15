
package ApiCommonData::Load::Plugin::InsertExprProfileFromProcessedResult;
@ISA = qw( GUS::PluginMgr::Plugin);

use strict;

use GUS::PluginMgr::Plugin;
use lib "$ENV{GUS_HOME}/lib/perl";
use ApiCommonData::Load::ExpressionProfileInsertion;
use Data::Dumper;

my $purposeBrief = <<PURPOSEBRIEF;
Insert a processed result from RAD into the easy-to-query Profile tables
PURPOSEBRIEF

my $purpose = <<PLUGIN_PURPOSE;
Insert a processed result from RAD into the easy-to-query Profile tables
PLUGIN_PURPOSE

my $tablesAffected =
	[['ApiDB.ProfileSet', ''],
        ['ApiDB.Profile', '']];


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
	      descr => 'the external database name with which to find the Study in RAD',
	      reqd => 1,
	      constraintFunc => undef,
	      isList => 0,
	     }),
   stringArg({name => 'extDbRlsVer',
	      descr => 'the version of the external database with which to find the Study in RAD',
	      reqd => 1,
	      constraintFunc => undef,
	      isList => 0,
	     }),
   stringArg({name => 'studyDescrip',
	      descr => 'Displayable description of study (not too long)',
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
   stringArg({name => 'protocolName',
	      descr => 'Name of protocol as found in RAD.Protocol.name',
	      reqd => 1,
	      constraintFunc => undef,
	      isList => 0,
	     }),
   enumArg({name => 'processingType',
	    descr => 'the type of processing used',
	    reqd => 1,
	    constraintFunc => undef,
	    enum => "RMAExpress, AffymetrixMas5, MOID",
	    isList => 0,
	   }),
   booleanArg({name => 'loadProfileElement',
	       descr => 'load the result values into separate rows in the ProfileElement table',
	       reqd => 0,
	       default => 0
	   }),
   booleanArg({name => 'tolerateMissingIds',
	       descr => '',
	       reqd => 0,
	       default => 0
	   }),
   booleanArg({name => 'averageReplicates',
	       descr => 'if there are replicate source IDs, average the values',
	       reqd => 0,
	       default => 0
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

  my $protocolName = $self->getArg('protocolName');
  my $studyDescrip = $self->getArg('studyDescrip');  # hard code for now
  my $arrayDesignName = $self->getArg('arrayDesignName');
  my $loadProfileElement = $self->getArg('loadProfileElement');
  my $tolerateMissingIds = $self->getArg('tolerateMissingIds');
  my $averageReplicates = $self->getArg('averageReplicates');

  my ($studyName, $header) = $self->makeHeader($extDbRlsId, $protocolName);

  my $profileRows = $self->getProfileRows($studyName,$protocolName,
					  $arrayDesignName, $header,
					  $extDbRlsId);
  print Dumper $profileRows;

  my $msg = &processInputProfileSet($self, $extDbRlsId, $header, $profileRows,
				    $studyName, $studyDescrip, 'gene',
				    $loadProfileElement, $tolerateMissingIds,
				    $averageReplicates);

  return $msg;

}

sub makeHeader {
  my ($self, $extDbRlsId, $protocolName) = @_;

 # sort by quantification_id to retain the desired order of quants
  my $sql = "
SELECT s.name, q.name, q.quantification_id
FROM Study.Study s, RAD.Protocol p,
     RAD.StudyAssay sa, RAD.Acquisition a, RAD.Quantification q
WHERE s.external_database_release_id = $extDbRlsId
  AND p.name = '$protocolName'
  AND sa.study_id = s.study_id
  AND a.assay_id = sa.assay_id
  AND q.acquisition_id = a.acquisition_id
  AND q.protocol_id = p.protocol_id
ORDER BY s.name, q.quantification_id
";

  my $stmt = $self->prepareAndExecute($sql);
  my $studyCount = 0;
  my $prevStudyName = 'pooh';
  my $header = [];
  my ($studyName, $elementName, $dontcare);
  while(($studyName, $elementName, $dontcare) = $stmt->fetchrow_array()) {
    if ($studyName ne $prevStudyName) {
      $studyCount++;
      $self->error("found more than one study: '$prevStudyName' and '$studyName'")
	if $studyCount > 1;
      $prevStudyName = $studyName;
    }
    push(@$header, $elementName);
  }
  $self->error("Couldn't find study for $extDbRlsId, $protocolName") unless ($studyCount);

  return ($studyName, $header);
}


sub getProfileRows {
  my ($self, $studyName,$protocolName,$arrayDesignName,$header, $extDbRlsId) = @_;

  $self->log("Getting the profile data from database");

  my $resultViewName = $self->getArg('processingType');
  my $resultColumnHash = {RMAExpress => 'RMA_EXPRESSION_MEASURE',
			  AffymetrixMas5 => '',
			  MOID => ''};
  my $resultColumn = $resultColumnHash->{$resultViewName};
  $self->error("can't find resultColumn") unless $resultColumn;

  my $sql = "
SELECT g.source_id, q.name, cer.$resultColumn
FROM Study.Study s, RAD.ArrayDesign ad, RAD.Protocol p,
     RAD.StudyAssay sa, RAD.Acquisition a, RAD.Quantification q,
     RAD.ShortOligoFamily  ce, RAD.$resultViewName cer,
     DoTS.GeneFeature g, RAD.CompositeElementNaSequence ces,
     DoTS.Transcript t
WHERE s.external_database_release_id = $extDbRlsId
  AND ad.name = '$arrayDesignName'
  AND p.name = '$protocolName'
  AND sa.study_id = s.study_id
  AND a.assay_id = sa.assay_id
  AND q.acquisition_id = a.acquisition_id
  AND q.protocol_id = p.protocol_id
  AND ce.array_design_id = ad.array_design_id
  AND cer.composite_element_id = ce.composite_element_id
  AND cer.quantification_id = q.quantification_id
  AND ce.composite_element_id = ces.composite_element_id
  AND ces.na_sequence_id = t.na_sequence_id
  AND g.na_feature_id = t.parent_id
  ORDER BY g.source_id
";


  # transform individual result rows to a single row with all results for a
  # sourceId
  my $stmt = $self->prepareAndExecute($sql);
  my $rows = [];
  my $sourceIdRowHash;
  my $count = 0;
  my $prevSourceId = "bleh";
  my ($sourceId, $quantName, $result);
  while (($sourceId, $quantName, $result) = $stmt->fetchrow_array()) {
    if ($sourceId ne $prevSourceId) {
      my $row = $self->makeSourceIdRow($sourceId, $sourceIdRowHash, $header);
      push(@$rows, $row) unless $count == 0;
      $prevSourceId = $sourceId;
      $sourceIdRowHash = {};
    }
    $sourceIdRowHash->{$quantName} = $result;
  }
  my $row = $self->makeSourceIdRow($sourceId, $sourceIdRowHash, $header);
  push(@$rows, $row);
  return $rows;
}

sub makeSourceIdRow {
  my ($self, $sourceId, $sourceIdRowHash, $header) = @_;
  my $row = [$sourceId];
  foreach my $quantName (@$header) { 
    push(@$row, $sourceIdRowHash->{$quantName});
  }
  return $row;
}


sub undoTables {
  my ($self) = @_;

  return ('DoTS.ExternalNASequence',
	  'RAD.ElementNASequence',
	 );
}

1;
