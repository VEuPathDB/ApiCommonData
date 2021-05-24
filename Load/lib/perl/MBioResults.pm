package ApiCommonData::Load::MBioResults;

# The generic class for loading results is ApiCommonData::Load::Plugin::InsertStudyResults
# but it wants data in a key-value format
# We also need to merge 16s and shotgun together

# Why the (OTU) and other suffixes:
# If we do this, good stuff will happen
# because the sample name needs to resolve with the sample details in ISA files
# These have a model
# Source -> Sample -> Extract -> Assay -> DataTransformation
# and DataTransformation has a cool suffix, "(OTU)"
# see: https://github.com/VEuPathDB/ApiCommonMetadataRepository/blob/master/ISA/metadata/MBSTDY0020/i_Investigation.xml
# known as technologyType in CBIL::TranscriptExpression::DataMunger::Loadable
#

@ISA = ('GUS::PluginMgr::Plugin');
use strict;
use warnings;
use GUS::PluginMgr::Plugin;

use List::Util qw/sum uniq/;
use GUS::Model::Results::LineageAbundance;
use GUS::Model::Results::FunctionalUnitAbundance;
use GUS::Model::SRes::OntologyTerm;
use GUS::Model::SRes::ExternalDatabase;
use GUS::Model::SRes::ExternalDatabaseRelease;
use GUS::Model::Study::Protocol;
use GUS::Model::Study::ProtocolApp;
use GUS::Model::Study::ProtocolAppNode;
use GUS::Model::Study::Study;
use GUS::Model::Study::StudyLink;
use GUS::Model::Study::Output;
use ApiCommonData::Load::MBioResultsTable::AsGus;


my $argsDeclaration = [
  stringArg({ name => 'datasetName',
    descr => 'Dataset name',
    isList    => 0,
    reqd  => 1,
    constraintFunc => undef,
  }),
  map {
  fileArg({name          => "${_}Path",
	  descr          => "File arg: $_", 
	  reqd           => 0,
	  mustExist      => 0,
	  format         => 'tab del',
	  constraintFunc => undef,
	  isList         => 0, 
	 })
  }
  qw/ampliconTaxa wgsTaxa pathwayAbundances pathwayCoverages level4ECs/
];

my $documentation = { purpose =>"",
		      purposeBrief     =>"",
		      notes            =>"",
		      tablesAffected   =>"",
		      tablesDependedOn =>"",
		      howToRestart     =>"",
		      failureCases     =>"", };

sub new {
  my ($class) = @_;
  my $self = {};
  bless($self,$class);

  $self->initialize({ requiredDbVersion => 4.0,
		      cvsRevision       => '$Revision$',
		      name              => ref($self),
		      argsDeclaration   => $argsDeclaration,
		      documentation     => $documentation});

  return $self;
}

sub registerDataset {
  my ($self, $datasetName) = @_;
#
# This is populated by the loadDataset call, there's entry corresponding to this in classes.xml
  my $externalDatabase =GUS::Model::SRes::ExternalDatabase->new({name => $datasetName}); 
  unless($externalDatabase->retrieveFromDB()){
    $self->error("Required external database name \"$datasetName\" either is not found in the database or returns more than one row from the database");
  }

  my $externalDatabaseRelease =GUS::Model::SRes::ExternalDatabaseRelease->new({external_database_id => $externalDatabase->getExternalDatabaseId}); 
  unless($externalDatabaseRelease->retrieveFromDB()){
    $self->error("Required external database release corresponding to external database name \"$datasetName\" either is not found in the database or returns more than one row from the database");
  }

  my $studyName = $datasetName;
  unless ($studyName =~ s/otuDADA2_(.*)_RSRC/$1/){
    $self->error("Dataset seems to match an external database + release, but I was expecting a name like /otuDADA2_(.*)_RSRC/ for the study to be called \"\$1\" and the investigation \"OTU Profiles \$1\" - might not be necessary but it was like that");
  }

  my $protocol = GUS::Model::Study::Protocol->new({name => "data transformation"});
  unless($protocol->retrieveFromDB()){
    $self->error("Required protocol name \"data transformation\" either is not found in the database or returns more than one row from the database");
  }

  my $investigation =  GUS::Model::Study::Study->new({
    name => "OTU Profiles $studyName",
    external_database_release_id => $externalDatabaseRelease->getExternalDatabaseReleaseId,
  });
  $investigation->submit;

  my $study = GUS::Model::Study::Study->new({
    name => $studyName,
    investigation_id => $investigation->getInvestigationId,
    external_database_release_id => $externalDatabaseRelease->getExternalDatabaseReleaseId,
  });
  $study->submit;

  return $protocol->getProtocolId, $investigation->getStudyId, $study->getStudyId;
  
}

sub getProtocolAppNodeIdsForSamples {
  my ($self, $datasetName, $protocolId, $investigationId, $studyId, $samples, $suffix) = @_;
  my $protocolApp = GUS::Model::Study::ProtocolApp->new({protocol_id => $protocolId});
  $protocolApp->submit;

  my $ontologyTerm = GUS::Model::SRes::OntologyTerm->new({name => "data item"});
  unless($ontologyTerm->retrieveFromDB()) {
    $self->error("Required ontology term \"data item\" either is not found in the database or returns more than one row from the database");
  }

  my %result;
  my $nodeOrderNum = 1;
  for my $sample (@{$samples}){

    my $protocolAppNode = GUS::Model::Study::ProtocolAppNode->new({name => $sample.$suffix, type_id => $ontologyTerm->getId(),  node_order_num => $nodeOrderNum});
    $protocolAppNode->submit;
    $nodeOrderNum++;

    GUS::Model::Study::Output
      ->new({protocol_app_id => $protocolApp->getProtocolAppId, protocol_app_node_id => $protocolAppNode->getProtocolAppNodeId})
      ->submit;

    GUS::Model::Study::StudyLink
      ->new({study_id => $investigationId, protocol_app_node_id => $protocolAppNode->getProtocolAppNodeId})
      ->submit;

    GUS::Model::Study::StudyLink
      ->new({study_id => $studyId, protocol_app_node_id => $protocolAppNode->getProtocolAppNodeId})
      ->submit;

    $result{$sample} = $protocolAppNode->getProtocolAppNodeId;
  }
  return \%result;
}

sub run {
  my ($self) = @_;

  my @data = $self->readData($self->getArgs());

  $self->uploadToDb(@data);
}

sub readData {
  my ($self, $args) = @_;
  my %args = %{$args};

  my $datasetName = $args{datasetName};
  $self->error("Required: datasetName") unless $datasetName;

  $self->error("Required: ampliconTaxaPath or ampliconTaxaPath") unless $args{ampliconTaxaPath} || $args{wgsTaxaPath};

  for my $arg (qw/pathwayAbundancesPath pathwayCoveragesPath level4ECsPath/){
    if ($args{wgsTaxaPath} and not $args{$arg}){
      $self->error("wgsTaxaPath present, but $arg not");
    }
  }

  my $maximumNumberOfObjects = 100;

  my $ampliconTaxaTable;

  if($args{ampliconTaxaPath}){
    $ampliconTaxaTable = ApiCommonData::Load::MBioResultsTable::AsGus->ampliconTaxa($args{ampliconTaxaPath});

    $maximumNumberOfObjects += 4 * @{$ampliconTaxaTable->{samples}};
    $maximumNumberOfObjects += @{$ampliconTaxaTable->{rows}};
  }

  my ($wgsTaxaTable, $level4EcsTable, $pathwaysTable);
  if ($args{wgsTaxaPath}){
    $wgsTaxaTable = ApiCommonData::Load::MBioResultsTable::AsGus->wgsTaxa($args{wgsTaxaPath});
    $level4EcsTable = ApiCommonData::Load::MBioResultsTable::AsGus->wgsFunctions("level4EC",$args{level4ECsPath});
    $pathwaysTable = ApiCommonData::Load::MBioResultsTable::AsGus->wgsPathways($args{pathwayAbundancesPath}, $args{pathwayCoveragesPath});

    $maximumNumberOfObjects += 4 * @{$wgsTaxaTable->{samples}};
    $maximumNumberOfObjects += @{$wgsTaxaTable->{rows}};
    $maximumNumberOfObjects += @{$level4EcsTable->{rows}};
    $maximumNumberOfObjects += @{$pathwaysTable->{rows}};
  } 
  return $datasetName, $ampliconTaxaTable, $wgsTaxaTable, $level4EcsTable, $pathwaysTable, $maximumNumberOfObjects;
}
sub uploadToDb {
  my ($self, $datasetName, $ampliconTaxaTable, $wgsTaxaTable, $level4EcsTable, $pathwaysTable, $maximumNumberOfObjects) = @_;

  my $setMaxObjects = sub {
    $self->getDb()->setMaximumNumberOfObjects(@_);
  };
  my $undefPointerCache = sub {
    $self->undefPointerCache();
  };
  my $submit = sub {
    my ($class, $o) = @_;
    $class->new($o)->submit;
  };
  my ($protocolId, $investigationId, $studyId) = $self->registerDataset($datasetName);

  if($ampliconTaxaTable){
    my $suffix = $wgsTaxaTable ? " (OTU from Amplicon)" : " (OTU)";
  
    $setMaxObjects->($maximumNumberOfObjects);
    my $protocolAppNodeIdsForSamples = $self->getProtocolAppNodeIdsForSamples($datasetName,$protocolId, $investigationId, $studyId, $ampliconTaxaTable->{samples}, $suffix);
    $undefPointerCache->();
    $ampliconTaxaTable->submitToGus($setMaxObjects, $undefPointerCache, $submit, $protocolAppNodeIdsForSamples);
  }

  if($wgsTaxaTable){
    my $suffix = " (OTU and functional profiles from WGS)";

    $setMaxObjects->($maximumNumberOfObjects);
    my $protocolAppNodeIdsForSamples = $self->getProtocolAppNodeIdsForSamples($datasetName,$protocolId, $investigationId, $studyId, $wgsTaxaTable->{samples}, $suffix);
    $undefPointerCache->();
    for my $table ($wgsTaxaTable, $level4EcsTable, $pathwaysTable){
      $table->submitToGus($setMaxObjects, $undefPointerCache, $submit, $protocolAppNodeIdsForSamples);
    }
  }
}

sub undoTables {
  return (
    'Results.FunctionalUnitAbundance',
    'Results.LineageAbundance',
    'Study.StudyLink',
    'Study.Output',
    'Study.ProtocolAppNode',
    'Study.Study',
    'Study.ProtocolApp',
  );

}

1;
