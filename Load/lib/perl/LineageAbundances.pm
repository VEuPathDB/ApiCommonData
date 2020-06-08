package ApiCommonData::Load::LineageAbundances;

# The generic class for loading results is ApiCommonData::Load::Plugin::InsertStudyResults
# but it wants data in a key-value format so we roll our own
# we also calculate relative abundance

@ISA = ('GUS::PluginMgr::Plugin');
use strict;
use warnings;
use GUS::PluginMgr::Plugin;

use List::Util qw/sum/;
use GUS::Model::Results::LineageAbundance;
use GUS::Model::SRes::OntologyTerm;
use GUS::Model::SRes::ExternalDatabase;
use GUS::Model::SRes::ExternalDatabaseRelease;
use GUS::Model::Study::Protocol;
use GUS::Model::Study::ProtocolApp;
use GUS::Model::Study::ProtocolAppNode;
use GUS::Model::Study::Study;
use GUS::Model::Study::StudyLink;
use GUS::Model::Study::Output;

# Compare to: 
my $argsDeclaration = [
 fileArg({name           => 'inputPath',
	  descr          => 'lineages are row labels, sample ids are column labels, and cells are absolute abundances.',
	  reqd           => 1,
	  mustExist      => 1,
	  format         => 'tab del',
	  constraintFunc => undef,
	  isList         => 0, 
	 }),
 stringArg({ name => 'datasetName',
    descr => 'Dataset name',
    isList    => 0,
    reqd  => 1,
    constraintFunc => undef,
  }),
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

sub registerDatasetAndGetProtocolAppNodeIdsForSamples {
  my ($self, $datasetName, $samples) = @_;

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
  
  my $protocolApp = GUS::Model::Study::ProtocolApp->new({protocol_id => $protocol->getProtocolId});
  $protocolApp->submit;

  my $ontologyTerm = GUS::Model::SRes::OntologyTerm->new({name => "data item"});
  unless($ontologyTerm->retrieveFromDB()) {
    $self->error("Required ontology term \"data item\" either is not found in the database or returns more than one row from the database");
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

  my %result;
  my $nodeOrderNum = 1;
  for my $sample (@{$samples}){
    # Why the (OTU) after the name:
    # If we do this, good stuff will happen
    # because the sample name needs to resolve with the sample details in ISA files
    # These have a model
    # Source -> Sample -> Extract -> Assay -> DataTransformation
    # and DataTransformation has a cool suffix, "(OTU)"
    # see: https://github.com/VEuPathDB/ApiCommonMetadataRepository/blob/master/ISA/metadata/MBSTDY0020/i_Investigation.xml
    # known as technologyType in CBIL::TranscriptExpression::DataMunger::Loadable

    my $protocolAppNode = GUS::Model::Study::ProtocolAppNode->new({name => "$sample (OTU)", type_id => $ontologyTerm->getId(),  node_order_num => $nodeOrderNum});
    $protocolAppNode->submit;
    $nodeOrderNum++;

    GUS::Model::Study::Output
      ->new({protocol_app_id => $protocolApp->getProtocolAppId, protocol_app_node_id => $protocolAppNode->getProtocolAppNodeId})
      ->submit;

    GUS::Model::Study::StudyLink
      ->new({study_id => $investigation->getStudyId, protocol_app_node_id => $protocolAppNode->getProtocolAppNodeId})
      ->submit;

    GUS::Model::Study::StudyLink
      ->new({study_id => $study->getStudyId, protocol_app_node_id => $protocolAppNode->getProtocolAppNodeId})
      ->submit;

    $result{$sample} = $protocolAppNode->getProtocolAppNodeId;
  }
  return \%result;
}

sub run {
  my ($self) = @_;

  my $inputPath = $self->getArg('inputPath');
  my $datasetName = $self->getArg('datasetName');

  $self->error("Does not exist: $inputPath") unless -e $inputPath;

  # Our Text::CSV is too old - hence the artisanal code instead of:
  # my @aoh = @{Text::CSV::csv(in=> $inputPath, headers => "auto")};
  
  open (my $fh, "<", $inputPath) or $self->error("$!: $inputPath");
 
  my $header = <$fh>;
  chomp $header;
  my ($__, @samples) = split "\t", $header;
  $self->error("No samples in $inputPath") unless @samples;
  my @aolh;
  while(<$fh>){
    chomp;
    my ($lineage, @counts) = split "\t";
    $self->error("Bad dimensions: $inputPath") unless $#counts == $#samples;
    my %h = map {
      $samples[$_] => $counts[$_]
    } 0..$#counts;
    push @aolh, [$lineage, \%h];
  }
  $self->error("No data rows in $inputPath") unless @aolh;


  my %totalCountPerSample;
  for my $h (map {$_->[1]} @aolh){
     for my $sample (@samples){
        $totalCountPerSample{$sample} += $h->{$sample};
     }
  }

  $self->getDb()->setMaximumNumberOfObjects(4 * scalar @samples + scalar @aolh + 100);

  my $protocolAppNodeIdsForSamples = $self->registerDatasetAndGetProtocolAppNodeIdsForSamples($self->getArg('datasetName'), \@samples);

  DATUM:
  for my $sample (@samples){
    LINEAGE:
    for my $p (@aolh){
    my ($lineage, $h) = @{$p};
      my $raw_count = $h->{$sample};
      next LINEAGE unless $raw_count;
      my $relative_abundance = sprintf("%.6f", $raw_count / $totalCountPerSample{$sample});
      GUS::Model::Results::LineageAbundance->new({
        lineage => $lineage,
        raw_count => $raw_count,
        relative_abundance => $relative_abundance,
        PROTOCOL_APP_NODE_ID => $protocolAppNodeIdsForSamples->{$sample},
      })->submit;
    }
    $self->undefPointerCache();
  };
    
}

sub undoTables {
  return (
    'Results.LineageAbundance',
    'Study.StudyLink',
    'Study.Output',
    'Study.ProtocolAppNode',
    'Study.Study',
    'Study.ProtocolApp',
  );

}

1;
