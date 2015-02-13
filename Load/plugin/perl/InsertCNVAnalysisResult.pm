package ApiCommonData::Load::Plugin::InsertCNVAnalysisResult;
@ISA = qw(ApiCommonData::Load::Plugin::InsertAnalysisResult);
# Subclass of InsertAnalysisResult to allow joining of source_id to NASequence and joining using logical link groups to ExtDBRls

use strict;

use GUS::Supported::GusConfig;
use GUS::PluginMgr::Plugin;
use ApiCommonData::Load::Plugin::InsertAnalysisResult;

use GUS::Model::Study::OntologyEntry;
use GUS::Model::RAD::Analysis;
use GUS::Model::RAD::AnalysisInput;

use GUS::Model::RAD::Protocol;
use GUS::Model::RAD::AnalysisParam;
use GUS::Model::RAD::ProtocolParam;

use GUS::Model::RAD::LogicalGroup;
use GUS::Model::RAD::LogicalGroupLink;
use GUS::Supported::Util;

$| = 1;

# ---------------------------------------------------------------------------
# Load Arguments
# ---------------------------------------------------------------------------

sub getArgumentsDeclaration{
  my $argsDeclaration =
    [

     booleanArg ({name => 'useSqlLdr',
                  descr => 'Set this to use sqlldr instead of objects.  Only implemented for DataTransformationResult',
                  reqd => 0,
                  default => 0
                 }),

     fileArg({name           => 'inputDir',
              descr          => 'Directory in which to find input files',
              reqd           => 1,
              mustExist      => 1,
              format         => '',
              constraintFunc => undef,
              isList         => 0, 
             }),

     fileArg({ name           => 'configFile',
               descr          => 'tab-delimited file with differential expression stats',
               reqd           => 1,
               mustExist      => 1,
               format         => '',
               constraintFunc => undef,
               isList         => 0,
             }),

     enumArg({ descr          => 'Table for joining source_id',
               name           => 'sourceIdType',
               isList         => 0,
               reqd           => 1,
               constraintFunc => undef,
               enum           => "NaSequence,NaFeature",
            }),

     enumArg({ descr          => 'View of analysisResultImp',
               name           => 'analysisResultView',
               isList         => 0,
               reqd           => 1,
               constraintFunc => undef,
               enum           => "DataTransformationResult,DifferentialExpression,ExpressionProfile",
             }),

     enumArg({ descr          => 'View of naFeatureImp (only required if sourceIdType is NaFeature)',
               name           => 'naFeatureView',
               isList         => 0,
               reqd           => 0,
               constraintFunc => undef,
               enum           => "ArrayElementFeature,GeneFeature,BindingSiteFeature", 
             }),

    ];
  return $argsDeclaration;
}

# ----------------------------------------------------------------------
# Documentation
# ----------------------------------------------------------------------

sub getDocumentation {
  my $purposeBrief = "Inserts Rad.Analysis and Rad.AnalysisResultImp View.  Creates the associated Rad.Protocol if it doesn't exist.  For each sample creates a logical group and a logical group link to ExtDbRls";

  my $purpose = "Inserts Rad.Analysis and Rad.AnalysisResultImp View.  Creates the associated Rad.Protocol if it doesn't exist.  For each sample creates a logical group and a logical group link to ExtDbRls";

  my $tablesAffected = [['RAD::Analysis', 'One Row to Identify this experiment'],['RAD::AnalysisResultImp', 'one row per line in the data file'],['RAD::Protocol', 'Will Create generic row if the specified protocol does not already exist'],['RAD::LogicalGroup', 'One row per sample'],['RAD::LogicalGroupLink', 'One row per sample, joins logical group to sample ExtDbRlsId']];

  my $tablesDependedOn = [['Study::OntologyEntry',  'new protocols will be assigned unknown_protocol_type'],
                          ['DoTS::NaFeatureImp', 'The id in the data file must correspond to an existing id in NaFeatureImp or NaSequenceImp'],
                          ['DOTS::NaSequenceImp', 'The id in the data file must correspond to an existing id in NaFeatureImp or NaSequenceImp']];

  my $howToRestart = "No restart";

  my $failureCases = "";

  my $notes = "The first column in the data file specifies a source_id from a view of NaFeatureImp or NaSequenceImp as specified in the command line.  Subsequent columns are view specific. (ex:  fold_change for DifferentialExpression OR float_value for DataTransformationResult).  The Config file has the following columns (no header):file analysis_name protocol_name protocol_type(OPTOINAL)";

  my $documentation = {purpose=>$purpose, purposeBrief=>$purposeBrief, tablesAffected=>$tablesAffected, tablesDependedOn=>$tablesDependedOn, howToRestart=>$howToRestart, failureCases=>$failureCases,notes=>$notes};

  return $documentation;
}

#--------------------------------------------------------------------------------

sub new {
  my ($class) = @_;
  my $self = {na_sequences => []
             };
  bless($self,$class);

  my $documentation = &getDocumentation();
  my $argumentDeclaration = &getArgumentsDeclaration();

  $self->initialize({requiredDbVersion => 3.6,
		             cvsRevision => '$Revision$',
                     name => ref($self),
                     revisionNotes => '',
                     argsDeclaration => $argumentDeclaration,
                     documentation => $documentation});

  return $self;
}

#--------------------------------------------------------------------------------

sub run {
  my ($self) = @_;

  my $config = $self->readConfig();

  my $totalLines;

  my $analysisResultView = $self->getArg('analysisResultView');
  my $sourceIdType = $self->getArg('sourceIdType');
  my $viewOnSourceType;

  if ($sourceIdType eq 'NaFeature'){
    $viewOnSourceType = $self->getArg('naFeatureView') or die ("naFeatureView must be specified if the sourceIdType is NaFeature");
  } elsif ($sourceIdType eq 'NaSequence'){
    $viewOnSourceType = 'NASequence';
  } else {
    die ("sourceIdType must be 'NaFeature' or 'NaSequence': $sourceIdType")
  }

  my $useSqlLdr = $self->getArg('useSqlLdr');

  if($analysisResultView ne 'DataTransformationResult' && $useSqlLdr) {
    $self->userError("DataTransformationResult is the only analysisResultVeiw currently supported with sqlldr");
  }

  my $class = "GUS::Model::RAD::$analysisResultView";
  eval "require $class";

  my $configHeader = shift @$config;

  $self->validateHeader($configHeader);

  foreach my $configRow (@$config) {
    my $dataFile = $configRow->[0];
    my $analysisName = $configRow->[1];
    my $protocolName = $configRow->[2];
    my $protocolType = $configRow->[3];
    my $sampleDatasetName = $configRow->[4];

    my $logicalGroup = $self->makeLogicalGroup($analysisName, $sampleDatasetName);#($profileElements, $analysisName, $profileSetName);

    my $protocol = $self->getProtocol($protocolName, $protocolType, $configHeader);

    my $analysis = $self->createAnalysis($protocol, $analysisName, $configHeader, $configRow, $logicalGroup);

    my $count = $self->processDataFile($analysis, $dataFile, $class, $viewOnSourceType, $useSqlLdr);

    $self->log("File Finished.  $count lines processed");

    $totalLines = $totalLines + $count;
  }

  my $totalInserts = $self->getTotalInserts();

  return "Processed $totalLines lines from data files and $totalInserts Total Inserts";
}

#--------------------------------------------------------------------------------

sub validateHeader {
  my ($self, $header) = @_;

  my @expected = ('datafile', 'analysisname', 'protocolname', 'protocoltype', 'sampleDatasetName');

  for(my $i = 0; $i < scalar @expected; $i++) {
    my $value = $header->[$i];
    $value =~ s/\s//g;

    my $e = $expected[$i];

    unless($value =~ /$e/i) {
      $self->userError("Config file missing missing expected Column: $e");
    }
  }
  return 1;
}


#--------------------------------------------------------------------------------

sub makeLogicalGroup {
  my ($self, $analysisName, $sampleDatasetName) = @_;
  return unless ($sampleDatasetName);

  my ($tableId) = $self->sqlAsArray( Sql => "select table_id from core.tableinfo where name = 'ExternalDatabaseRelease'");

  my $logicalGroupName = "$analysisName INPUTS";
  my $logicalGroup = GUS::Model::RAD::LogicalGroup->new({name => $logicalGroupName});

  # May be able to write this directly in to the config from the workflow and skip this step!
  my ($extDbRlsId) = $self->sqlAsArray( Sql => "select edr.external_database_release_id from sres.externaldatabase ed, sres.externaldatabaserelease edr where ed.name = '$sampleDatasetName' and ed.external_database_id = edr.external_database_id" );

  unless ($extDbRlsId) {
    $self->userError("No ExtDbRlsId can be associated with sample dataset name $sampleDatasetName");
  }

    my $link = GUS::Model::RAD::LogicalGroupLink->new({table_id => $tableId, row_id => $extDbRlsId});
    $link->setParent($logicalGroup);
    $link->submit();
  return $logicalGroup;
}

#--------------------------------------------------------------------------------

sub getNaFeatureId {
  my ($self, $sourceId, $viewOnSourceType) = @_;

  my @features;

  if ($viewOnSourceType eq 'GeneFeature'){
      my $naFeatureId =  GUS::Supported::Util::getGeneFeatureId($self, $sourceId);

      push @features, $naFeatureId;
  }elsif ($viewOnSourceType eq 'NASequence'){
      my $naSequenceId = GUS::Supported::Util::getNASequenceId($self, $sourceId);
      push @features, $naSequenceId;
  }else{
      my $naFeatureIds =  GUS::Supported::Util::getNaFeatureIdsFromSourceId($self, $sourceId, $viewOnSourceType);

      @features = @$naFeatureIds;
  }

  if(scalar @features > 1) {
    $self->log("WARN:  Several NAFeatures are found for source_id $sourceId. Loading multiple rows.");
  }
  return \@features;

}

1;
