package ApiCommonData::Load::GeneConfMulticlassSam;
use base qw(GUS::Community::RadAnalysis::AbstractProcessor);

use strict;

use GUS::Community::RadAnalysis::RadAnalysisError;
use GUS::Community::RadAnalysis::ProcessResult;

use GUS::Model::RAD::Protocol;
use GUS::Model::RAD::ProtocolQCParam;
use GUS::Model::RAD::ProtocolParam;
use GUS::Model::RAD::LogicalGroup;
use GUS::Model::RAD::LogicalGroupLink;

use GUS::Model::Core::TableInfo;

use  GUS::ObjRelP::DbiDatabase;

use Data::Dumper;

=head1 NAME

ApiCommonData::Load::GeneConfTwoMulticlassSam

=head1 SYNOPSIS

  my $args = {arrayDesignName => 'ARRAYDESIGN',
              ...
             };

  my $processer = ApiCommonData::Load::GeneConfTwoMulticlassSam->new($args);
  my $results = $processer->process();

=head1 CONFIG ARGS

=over 4

=item C<arrayDesignName>

RAD::ArrayDesign name

=item C<studyName>

Study::Study Name

=item C<inputNames>

The names for the input (RAD::LogicalGroup)

=item C<samInputFile>

How should the input file be named??

=back

=head1 DESCRIPTION

Subclass of GUS::Community::RadAnalysis::AbstractProcessor which implements the process().
Query Database to create a SamInput file and then Run Sam in R

=head1 TODO

  -Get Data from Analysis Tables (2 channel Experiments)

=cut

my $RESULT_VIEW = 'RAD::DifferentialExpression';
my $XML_TRANSLATOR = 'samMulticlassGeneConf';

#--------------------------------------------------------------------------------

sub new {
  my ($class, $argsHash) = @_;

  unless(ref($argsHash) eq 'HASH') {
    GUS::Community::RadAnalysis::InputError->new("Must provide a hashref to the constructor of TwoClassPage")->throw();
  }

  my $args = $argsHash;

  unless($args->{arrayDesignName}) {
    GUS::Community::RadAnalysis::InputError->new("Parameter [arrayDesignName] is missing in the config file")->throw();
  }

  unless($args->{studyName}) {
    GUS::Community::RadAnalysis::InputError->new("Parameter [studyName] is missing in the config file")->throw();
  }

  unless($args->{inputNames}) {
    GUS::Community::RadAnalysis::InputError->new("Parameters [inputNames] is required in the config file")->throw();
  }

  unless($args->{samInputFile}) {
    GUS::Community::RadAnalysis::InputError->new("Parameter [samInputFile] is missing in the config file")->throw();
  }

  unless($args->{rVersion}) {
    GUS::Community::RadAnalysis::InputError->new("Parameter [rVersion] is required in the config file")->throw();
  }

  unless($args->{isDataLogged} == 1 || $args->{isDataLogged} == 0) {
    GUS::Community::RadAnalysis::InputError->new("Parameter [isDataLogged] is missing in the config file")->throw();
  }

  # Default Sam Values
  unless($args->{knnNeighbors}) {
    $args->{knnNeighbors} = 10;
  }
  unless($args->{testStatisic}) {
    $args->{testStatistic} = "standard";
  }
  unless($args->{numPermutations}) {
    $args->{numPermutations} = 100;
  }

  bless $args, $class;
}

#--------------------------------------------------------------------------------

sub getArrayDesignName {$_[0]->{arrayDesignName}}
sub getStudyName {$_[0]->{studyName}}

sub getInputNames {$_[0]->{inputNames}}

sub getQuantificationView {$_[0]->{quantificationView}}
sub getAnalysisView {$_[0]->{analysisView}}

sub getSamInputFile {$_[0]->{samInputFile}}

sub getRVersion {$_[0]->{rVersion}}
sub getIsDataLogged {$_[0]->{isDataLogged}}

sub getKnnNeighbors {$_[0]->{knnNeighbors}}
sub getTestStatistic {$_[0]->{testStatistic}}
sub getNumPermutations {$_[0]->{numPermutations}}

#--------------------------------------------------------------------------------

sub process {
  my ($self) = @_;

  my $database;
  unless($database = GUS::ObjRelP::DbiDatabase->getDefaultDatabase()) {
    GUS::Community::RadAnalysis::ProcessorError->new("Package [UserProvidedNorm] Requires Default DbiDatabase")->throw();
  }

  my $dbh = $database->getQueryHandle();

  my $logicalGroups = $self->setupLogicalGroups($dbh);

  # Get all the elements for an ArrayDesign
  my $arrayDesignName = $self->getArrayDesignName();
  my $arrayTable = $self->queryForArrayTable($dbh, $arrayDesignName);

  my $allElements = $self->queryForElements($dbh, $arrayDesignName);

  # make the page Input file
  my $quantView = $self->getQuantificationView();
  my $analysisView = $self->getAnalysisView();

  my $samMatrix = $self->createDataMatrixFromLogicalGroups($logicalGroups, $quantView, $analysisView, $dbh);

  $self->writeSamInputFile($samMatrix, $logicalGroups);

  # run sam
  my $resultFile = $self->runR();

  # make the Process Result
  my $result = GUS::Community::RadAnalysis::ProcessResult->new();

  $result->setArrayDesignName($arrayDesignName);
  $result->setArrayTable($arrayTable);
  $result->setResultFile($resultFile);
  $result->setResultView($RESULT_VIEW);
  $result->setXmlTranslator($XML_TRANSLATOR);

  my $protocol = $self->setupProtocol();
  $result->setProtocol($protocol);

  my $paramValues = $self->setupParamValues();
  $result->addToParamValuesHashRef($paramValues);

  $result->addLogicalGroups(@$logicalGroups);

  return [$result];
}


#--------------------------------------------------------------------------------

sub setupLogicalGroups {
  my ($self, $dbh) = @_;

  my @logicalGroups;

  my $coreHash = $self->queryForTable($dbh);
  my $studyName = $self->getStudyName();

  my $logicalGroupNames = $self->getInputNames();

  foreach my $name (@$logicalGroupNames) {
    my $analysisLogicalGroup = GUS::Model::RAD::LogicalGroup->new({name => $name, 
                                                                   category => 'analysis',
                                                                  });

    my $quantificationLogicalGroup = GUS::Model::RAD::LogicalGroup->new({name => $name,
                                                                         category => 'quantification',
                                                                        });

    my $retrievedAnalysis = $analysisLogicalGroup->retrieveFromDB();
    my $retrievedQuantification = $quantificationLogicalGroup->retrieveFromDB();

    unless($retrievedAnalysis || $retrievedQuantification) {
      GUS::Community::RadAnalysis::ProcessorError->
          new("Could not retrieve Analysis or Quantification LogicalGroup")->throw();
    }

    if($retrievedAnalysis) {
      my @links = $analysisLogicalGroup->getChildren('RAD::LogicalGroupLink', 1);
      map { $_->setParent($analysisLogicalGroup) } @links;

      push(@logicalGroups, $analysisLogicalGroup);
    }

    if($retrievedQuantification) {
      my @links = $quantificationLogicalGroup->getChildren('RAD::LogicalGroupLink', 1);
      map { $_->setParent($quantificationLogicalGroup) } @links;

      push(@logicalGroups, $quantificationLogicalGroup);
    }
  }

  return \@logicalGroups;
}



#--------------------------------------------------------------------------------

sub setupParamValues {
  my ($self) = @_;

  my $values = {regression_method => 'standard',
                knn_neighbors => $self->getKnnNeighbors(),
                data_is_logged => $self->getIsDataLogged(),
                r_version => $self->getRVersion(),
                software_language => 'R',
                statistic => $self->getTestStatistic(),
                num_permutations => $self->getNumPermutations(),
               };

  return $values;
}



#--------------------------------------------------------------------------------

sub setupProtocol {
  my ($self) = @_;

  my $protocol = GUS::Model::RAD::Protocol->new({name => 'SAM Multiclass -- differential expression'});

  unless($protocol->retrieveFromDB) {
    $protocol->setUri('http://www-stat.stanford.edu/~tibs/SAM/index.html');
    $protocol->setProtocolDescription('This protocol refers to the SAM (Statistical Analysis of Microarrays) program when used with the response type: multi. The input to SAM is gene expression measurements from a set of microarray experiments, as well as a response variable from each experiment. SAM computes a statistic for each gene, measuring the strength of the relationship between gene expression and the response variable. It uses repeated permutations of the data to determine if the expression of any genes are significantly related to the response. The cutoff for significance is determined by a tuning parameter delta, chosen by the user based on the false positive rate. One can also choose a fold change parameter, to ensure that called genes change at least a pre-specified amount.	');

    $protocol->setSoftwareDescription('There are R and Excel Implementations');

    my $oe = GUS::Model::Study::OntologyEntry->new({value => 'differential_expression'});
    unless($oe->retrieveFromDB) {
      die "Cannot retrieve RAD::OntologyEntry [differential_expression]";
    }

    $protocol->setProtocolTypeId($oe->getId());
  }

  my $oeHash = $self->getOntologyEntries();

  $self->setupProtocolParams($protocol, $oeHash);

  return $protocol;
}


#--------------------------------------------------------------------------------

sub getOntologyEntries {
  my ($self) = @_;

  my %ontologyEntries;

  my @dataTypes = ('positive_integer',
                   'string_datatype',
                   'boolean',
                  );

  foreach(@dataTypes) {
    my $oe = GUS::Model::Study::OntologyEntry->new({value => $_,
                                                    category => 'DataType',
                                                   });

    unless($oe->retrieveFromDB) {
      die "Cannot retrieve RAD::OntologyEntry [$_]";
    }
 
    $ontologyEntries{$_} = $oe;
  }

  return \%ontologyEntries;
}

#--------------------------------------------------------------------------------

sub setupProtocolParams {
  my ($self, $protocol, $oeHash) = @_;

  my %params = (regression_method => 'string_datatype',
                knn_neighbors => 'positive_integer',
                data_is_logged => 'boolean',
                r_version => 'string_datatype',
                software_language => 'string_datatype',
                statistic => 'string_datatype',
                num_permutations => 'positive_integer',
               );

  my @protocolParams = $protocol->getChildren('RAD::ProtocolParam', 1);

  if(scalar(@protocolParams) == 0) {

    foreach(keys %params) {
      my $dataType = $params{$_};
      my $oe = $oeHash->{$dataType};

      my $oeId = $oe->getId();

      my $param = GUS::Model::RAD::ProtocolParam->new({name => $_,
                                                       data_type_id => $oeId,
                                                      });

      push(@protocolParams, $param);
    }
  }

  foreach my $param (@protocolParams) {
    $param->setParent($protocol);
  }

  return \@protocolParams;
}



#--------------------------------------------------------------------------------

sub runR {
  my ($self) = @_;

  my $inputFile = $self->getSamInputFile();
  my $outputFile = $inputFile . ".out";

  my $knnNeighbors = $self->getKnnNeighbors();
  my $statistic = $self->getTestStatistic();
  my $numPermutations = $self->getNumPermutations();

  my $script =  $ENV{GUS_HOME} . "/bin/multiClassSam.r";

  unless(-e $script) {
    GUS::Community::RadAnalysis::ProcessorError->new("File [$script] does not exist")->throw();
  }

  my $args = "knnNeighbors = $knnNeighbors; inputFile = \"$inputFile\"; outputFile = \"$outputFile\"; statistic = \"$statistic\"; numPermutations = $numPermutations; ";

  my $command = "echo '$args' | cat - $script  | R --no-save";
  #print STDERR $command."\n";

  my $systemResult = system($command);

  unless($systemResult / 256 == 0) {
    GUS::Community::RadAnalysis::ProcessorError->new("Error while attempting to run R:\n$command")->throw();
  }

  return $outputFile;
}

#--------------------------------------------------------------------------------

sub writeSamInputFile {
  my ($self, $input, $logicalGroups) = @_;

  my $samIn = $self->getSamInputFile();
  open(FILE, "> $samIn") or die "Cannot open file [$samIn] for writing: $!";

  my %names;

  foreach my $lg (@$logicalGroups) {
    my $name = $lg->getName();
    my @links = $lg->getChildren('RAD::LogicalGroupLink');
    my $childCount = scalar(@links);

    $names{$name} = $childCount + $names{$name};
  }

  my @headerNames = sort keys %names;  

  my @header;
  my $group = 1;

  foreach my $name (@headerNames) {
    push(@header, @{$self->getSamHeader($group, $names{$name})});
    $group++;
  }

  print FILE join("\t", "id", @header) . "\n";

  foreach my $element (keys %$input) {
    my @output;

    foreach my $name (@headerNames) {
      push @output, @{$input->{$element}->{$name}};
    }

    my $naCount;
    map {$naCount++ if($_ eq 'NA')} @output;

    # Don't print if they are all NA's
    unless(scalar(@output) == $naCount) {
      print FILE join("\t", $element, @output) . "\n";
    }
  }
  close FILE;
}

#--------------------------------------------------------------------------------

sub getSamHeader {
  my ($self, $value, $n) = @_;

  my @values;

  foreach(1..$n) {
    push(@values, $value);
  }
  return \@values;
}

#--------------------------------------------------------------------------------

1;
