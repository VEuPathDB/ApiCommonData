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

sub parseSamplesTsv {
  my ($self, $inputPath) = @_; 
  # Our Text::CSV is too old - hence the artisanal code instead of:
  # my @aoh = @{Text::CSV::csv(in=> $inputPath, headers => "auto")};
  
  open (my $fh, "<", $inputPath) or $self->error("$!: $inputPath");
 
  my $header = <$fh>;
  $self->error("No header in $inputPath") unless $header;
  chomp $header;
  my ($__, @samples) = split "\t", $header;
  $self->error("No samples in $inputPath") unless @samples;
  my @rowSampleHashPairs;
  while(<$fh>){
    chomp;
    my ($row, @counts) = split "\t";
    $self->error("Bad dimensions: $inputPath") unless $#counts == $#samples;
    my %h = map {
      $samples[$_] => $counts[$_]
    } 0..$#counts;
    push @rowSampleHashPairs, [$row, \%h];
  }
  $self->error("No data rows in $inputPath") unless @rowSampleHashPairs;
  return \@samples, \@rowSampleHashPairs;
}

# Expect output in HUMAnN format
# ANAEROFRUCAT-PWY: homolactic fermentation
# ARGDEG-PWY: superpathway of L-arginine, putrescine, and 4-aminobutanoate degradation|g__Escherichia.s__Escherichia_coli
# 1.1.1.103: L-threonine 3-dehydrogenase|g__Escherichia.s__Escherichia_coli
# 1.1.1.103: L-threonine 3-dehydrogenase|unclassified
# 7.2.1.1: NO_NAME

sub detailsFromRowName {
  my ($row) = @_;

  (my $name = $row) =~ s{:.*}{};

  my $description;
  $row =~ m{^.*?:\s*([^\|]+)};
  $description = $1 if $1 and $1 ne "NO_NAME";
  
  
  my ($__, $lineage) = split("\|", $row);

  my $species;
  if($row =~ m{\|}){
    $species = $row;
    $species =~ s{^.*\|}{};
    $species =~ s{^.*s__}{};
    $species = unmessBiobakerySpecies($species);
  }

  return {name => $name, description => $description, species => $species};
}

# Expect output in metaphlan format
# Skip all taxa not at species level - they are summary values
sub prepareWgsTaxa {
  my ($dataPairs) = @_;

  my @rows;
  my @dataPairsResult;
  for my $p (@{$dataPairs}) {
    my ($row, $h) = @$p;
    $row = maybeGoodMetaphlanRow($row);
    next unless $row;
    push @rows, $row;
    push @dataPairsResult, [$row, $h];
  }
  return \@rows, \@dataPairsResult;
}

# Biobakery tools use mangled species names, with space, dash, and a few others changed to underscore
# Try make them good enough again
sub unmessBiobakerySpecies {
  my ($species) = @_;
# Species with IDs
  $species =~ s{_sp_}{ sp. };

# genus, maybe a different genus in []
  $species =~ s{^(\[?[A-Z][a-z]+\]?)_}{$1 };

# last word, like "Ruminococcus gnavus group"
  $species =~ s{_([a-z]+)$}{ $1};

  $species =~ s{oral_taxon_(\d+)$}{oral taxon $1};
  return $species;
}

sub maybeGoodMetaphlanRow {
  my ($row) = @_;
  return if $row eq 'UNKNOWN';
  return unless $row =~ m{k__(.*)\|p__(.*)\|c__(.*)\|o__(.*)\|f__(.*)\|g__(.*)\|s__(.*)};
  return join(";", $1, $2, $3, $4, $5, $6, unmessBiobakerySpecies($7));
}

sub prepareFunctionAbundance {
  my ($self, $samples, $dataPairs) = @_;

  my %result;
  my %rows;
  for my $p (@{$dataPairs}) {
    my ($row, $h) = @$p;
    next if $row =~ m{UNMAPPED|UNGROUPED|UNINTEGRATED};
    my $details = detailsFromRowName($row);
    $rows{$row}++;
    for my $sample (@{$samples}){
      $result{$sample}{$row} = {%{$details}, abundance_cpm => $h->{$sample}};
    }
  }
  my @rows = sort keys %rows;

  return \@rows, \%result;
}

sub mergeAbundanceAndCoverage {
  my ($self, $samples, $dataPairsA, $dataPairsC) = @_;


  my %result;
  my %rowsA;
  for my $p (@{$dataPairsA}) {
    my ($row, $h) = @$p;

    next if $row =~ m{UNMAPPED|UNGROUPED|UNINTEGRATED};
    my $details = detailsFromRowName($row);

    $rowsA{$row}++;
    for my $sample (@{$samples}){
      $result{$sample}{$row} = { %{$details} , abundance_cpm => $h->{$sample}};
    } 
  }
  my $numRowsC;

  for my $p (@{$dataPairsC}) {
    my ($row, $h) = @{$p};
    next if $row =~ m{UNMAPPED|UNGROUPED|UNINTEGRATED};

    $self->error("Inconsistent rows between abundance and coverage files: row $row in the coverage file missing from the abundance file")
      unless defined $rowsA{$row};
    $numRowsC++;

    for my $sample (@${samples}){

      $self->error("Inconsistent samples between abundance and coverage files: row $row, sample $sample in the coverage file missing from the abundance file")
         unless defined $result{$sample}{$row}{abundance_cpm};

      $result{$sample}{$row}{coverage_fraction} = $h->{$sample};
    } 
  }
 
  my @rows = sort keys %rowsA;
  $self->error(sprintf("Coverage file had %s more rows than the abundance file?", $numRowsC - @rows))
    unless @rows == $numRowsC;

  return \@rows, \%result; 
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

  $self->error("Nothing to upload?") unless $args{ampliconTaxaPath} || $args{wgsTaxaPath};

  for my $arg (qw/pathwayAbundancesPath pathwayCoveragesPath level4ECsPath/){
    if ($args{wgsTaxaPath} and not $args{$arg}){
      $self->error("wgsTaxaPath present, but $arg not");
    }
  }

 
  my %data;
  for my $arg (grep {$args{$_}} qw/ampliconTaxaPath wgsTaxaPath pathwayAbundancesPath pathwayCoveragesPath level4ECsPath/){
    my ($s, $r) =  $self->parseSamplesTsv($args{$arg});
    $data{$arg} = [$s,$r];
  }
 
  my $maximumNumberOfObjects = 100;

  my $ampliconSamples;
  my $ampliconTaxa;

  if($data{ampliconTaxaPath}){
    $ampliconSamples = $data{ampliconTaxaPath}->[0];
    $ampliconTaxa = $data{ampliconTaxaPath}->[1];

    $maximumNumberOfObjects += 4 * @{$ampliconSamples};
    $maximumNumberOfObjects += @{$ampliconTaxa};
  }

  my $wgsSamples;
  my ($wgsTaxaRows, $wgsTaxa, $level4ECRows, $level4ECData, $pathwayRows, $pathwayData);
  if ($args{wgsTaxaPath}){
    my @wgsSamples = uniq map {@{$_->[0]}} @data{qw/wgsTaxaPath pathwayAbundancesPath pathwayCoveragesPath level4ECsPath/};
    $wgsSamples = \@wgsSamples;
    for my $p (@data{qw/wgsTaxaPath pathwayAbundancesPath pathwayCoveragesPath level4ECsPath/}){
      if (@wgsSamples > @{$p->[0]}){
        $self->error("Inconsistent sample names across WGS files");
      }
    }
    ($wgsTaxaRows, $wgsTaxa) = prepareWgsTaxa($data{wgsTaxaPath}->[1]);

    ($level4ECRows, $level4ECData) = $self->prepareFunctionAbundance($wgsSamples, $data{level4ECsPath}->[1]);
    
    ($pathwayRows, $pathwayData) = $self->mergeAbundanceAndCoverage($wgsSamples, $data{pathwayAbundancesPath}->[1],  $data{pathwayCoveragesPath}->[1]);

    $maximumNumberOfObjects += 4 * @{$wgsSamples};
    $maximumNumberOfObjects += @{$wgsTaxaRows};
    $maximumNumberOfObjects += @{$level4ECRows};
    $maximumNumberOfObjects += @{$pathwayRows};
  } 
  return $datasetName, $ampliconSamples, $ampliconTaxa, $wgsSamples, $wgsTaxaRows, $wgsTaxa, $level4ECRows, $level4ECData, $pathwayRows, $pathwayData, $maximumNumberOfObjects;
}
sub uploadToDb {
  my ($self, $datasetName, $ampliconSamples, $ampliconTaxa, $wgsSamples, $wgsTaxaRows, $wgsTaxa, $level4ECRows, $level4ECData, $pathwayRows, $pathwayData, $maximumNumberOfObjects) = @_;

  $self->getDb()->setMaximumNumberOfObjects($maximumNumberOfObjects);


  my ($protocolId, $investigationId, $studyId) = $self->registerDataset($datasetName);

  if($ampliconSamples){
    my $suffix = $wgsSamples ? " (OTU from Amplicon)" : " (OTU)";
  
    my $protocolAppNodeIdsForSamples = $self->getProtocolAppNodeIdsForSamples($datasetName,$protocolId, $investigationId, $studyId, $ampliconSamples, $suffix);
    $self->uploadTaxa($protocolAppNodeIdsForSamples, $ampliconSamples, $ampliconTaxa);
  }

  if($wgsSamples){
    my $suffix = " (OTU and functional profiles from WGS)";
    my $protocolAppNodeIdsForSamples = $self->getProtocolAppNodeIdsForSamples($datasetName,$protocolId, $investigationId, $studyId, $wgsSamples, $suffix);

    $self->uploadTaxa($protocolAppNodeIdsForSamples, $wgsSamples, $wgsTaxa);
    $self->uploadFunctionalUnits($protocolAppNodeIdsForSamples, $wgsSamples, $level4ECRows, $level4ECData, "level4EC");
    $self->uploadFunctionalUnits($protocolAppNodeIdsForSamples, $wgsSamples, $pathwayRows, $pathwayData, "pathway");
  }
}

sub uploadFunctionalUnits {
  my ($self, $protocolAppNodeIdsForSamples, $samples, $rows, $rowData, $unitType) = @_;

  for my $sample (@{$samples}){
    for my $row (@{$rows}){
      GUS::Model::Results::FunctionalUnitAbundance->new({
        %{$rowData->{$sample}{$row}},
        unit_type => $unitType,
        PROTOCOL_APP_NODE_ID => $protocolAppNodeIdsForSamples->{$sample},
      })->submit;
    }
    $self->undefPointerCache();
  }
}

sub uploadTaxa {
  my ($self, $protocolAppNodeIdsForSamples, $samples, $rowSampleHashPairs) = @_;
  my @samples = @{$samples};
  my @rowSampleHashPairs = @{$rowSampleHashPairs};
  my %totalCountPerSample;
  for my $h (map {$_->[1]} @rowSampleHashPairs){
     for my $sample (@samples){
        $totalCountPerSample{$sample} += $h->{$sample};
     }
  }

  DATUM:
  for my $sample (@samples){
    LINEAGE:
    for my $p (@rowSampleHashPairs){
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
