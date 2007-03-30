package ApiCommonData::Load::ExpressionProfileAnalysis;
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

ApiCommonData::Load::ExpressionProfileAnalysis;

=head1 SYNOPSIS

  my $args = {arrayDesignName => 'ARRAYDESIGN',
              ...
             };

  my $processer = ApiCommonData::Load::ExpressionProfileAnalysis->new($args);
  my $results = $processer->process();

=head1 CONFIG ARGS

=over 4

=item C<arrayDesignName>

RAD::ArrayDesign name

=item C<rVersion>

Version of R which you are running

=item C<inputFileName>

Full path for the file TO BE WRITTEN

=item C<quantificationUris>

RAD::Quantification uris

=item C<analysisNames>

 **Not yet implemented** (Analyses do not have names... must use analysisparam)

=item C<studyName>

Study::Study Name

=item C<inputName>

The name for the input (RAD::LogicalGroup)

=item C<isDataLogged>

Is the data logged (1 or 0)

=item C<baseX>

If the data is logged... what base?

=back

=head1 DESCRIPTION

Subclass of GUS::Community::RadAnalysis::AbstractProcessor which implements the process().
Query the database ... if the data is logged, unlog it ... calc the mean expression, stderr, stdev, and percentile rank
The Executable for R must be in your PATH.

=head1 TODO

  -Get Data from Analysis Tables (2 channel Experiments)

=cut

#--------------------------------------------------------------------------------

my $RESULT_VIEW = 'RAD::ExpressionProfile';

#--------------------------------------------------------------------------------

sub new {
  my ($class, $argsHash) = @_;

  unless(ref($argsHash) eq 'HASH') {
    GUS::Community::RadAnalysis::InputError->new("Must provide a hashref to the constructor of TwoClassPage")->throw();
  }

  my $args = $argsHash;

  $args->{quantificationUris} = [] unless($argsHash->{quantificationUris});
  $args->{analysisNames} = [] unless($argsHash->{analysisNames});

  unless($args->{arrayDesignName}) {
    GUS::Community::RadAnalysis::InputError->new("Parameter [arrayDesignName] is missing in the config file")->throw();
  }

  unless($args->{studyName}) {
    GUS::Community::RadAnalysis::InputError->new("Parameter [studyName] is missing in the config file")->throw();
  }

  unless($args->{inputFileName}) {
    GUS::Community::RadAnalysis::InputError->new("Parameter [inputFileName] is missing in the config file")->throw();
  }

  unless($args->{inputName}) {
    GUS::Community::RadAnalysis::InputError->new("Parameter [inputName] is required in the config file")->throw();
  }

  unless($args->{isDataLogged} == 1 || $args->{isDataLogged} == 0) {
    GUS::Community::RadAnalysis::InputError->new("Parameter [isDataLogged] is missing in the config file")->throw();
  }

  if($args->{isDataLogged} && !$args->{baseX}) {
    GUS::Community::RadAnalysis::InputError->new("Parameter [baseX] must be given when specifying Data Is Logged")->throw();
  }

  unless($args->{rVersion}) {
    GUS::Community::RadAnalysis::InputError->new("Parameter [rVersion] is required in the config file")->throw();
  }

  bless $args, $class;
}

#--------------------------------------------------------------------------------

sub getArrayDesignName {$_[0]->{arrayDesignName}}
sub getStudyName {$_[0]->{studyName}}

sub getInputName {$_[0]->{inputName}}
sub getInputFileName {$_[0]->{inputFileName}}

sub getIsDataLogged {$_[0]->{isDataLogged}}

sub getQuantificationView {$_[0]->{quantificationView}}
sub getQuantificationUris {$_[0]->{quantificationUris}}

sub getAnalysisView {$_[0]->{analysisView}}
sub getAnalysisNames {$_[0]->{analysisNames}}

sub getBaseX {$_[0]->{baseX}}
sub getRVersion {$_[0]->{rVersion}}

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

  # make the data matrix
  my $quantView = $self->getQuantificationView();
  my $analysisView = $self->getAnalysisView();

  my $data = $self->createDataMatrixFromLogicalGroups($logicalGroups, $quantView, $analysisView, $dbh);

  # write the file
  $self->writeFile($data, $logicalGroups);

  # run page
  my $resultFile = $self->runR();

  # make the Process Result
  my $result = GUS::Community::RadAnalysis::ProcessResult->new();

  $result->setArrayTable($arrayTable);
  $result->setResultFile($resultFile);
  $result->setResultView($RESULT_VIEW);

  my $protocol = $self->setupProtocol();
  $result->setProtocol($protocol);

  $result->addToParamValuesHashRef({r_version => $self->getRVersion()});
  $result->addLogicalGroups(@$logicalGroups);

  return [$result];
}


#--------------------------------------------------------------------------------

sub setupLogicalGroups {
  my ($self, $dbh) = @_;

  my @logicalGroups;

  my $studyName = $self->getStudyName();

  my $name = $self->getInputName();

  my $uris = $self->getQuantificationUris();
  my $analysisNames = $self->getAnalysisNames();


  if(scalar(@$uris) > 0) {
    my $logicalGroup = $self->makeLogicalGroup($name, '', 'quantification', $uris, $studyName, $dbh);

    push(@logicalGroups, $logicalGroup);
  }

  if(scalar(@$analysisNames) > 0) {
    my $logicalGroup = $self->makeLogicalGroup($name, '', 'analysis', $analysisNames, $studyName, $dbh);

    push(@logicalGroups, $logicalGroup);
  }

  return \@logicalGroups;
}



#--------------------------------------------------------------------------------

sub setupProtocol {
  my ($self) = @_;

  my $protocol = GUS::Model::RAD::Protocol->new({name => 'R Expression Statistics'});

  unless($protocol->retrieveFromDB) {
    $protocol->setProtocolDescription('R is used to calculate a mean, standard deviation, standard error, rank, and percentile for each (composite) element on the array');
    $protocol->setSoftwareDescription('The R Project for Statistical Computing');

    my $oe = GUS::Model::Study::OntologyEntry->new({value => 'across_bioassay_data_set_function'});
    unless($oe->retrieveFromDB) {
      die "Cannot retrieve RAD::OntologyEntry [across_bioassay_data_set_function]";
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

  my @dataTypes = ('string_datatype',
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

  my %params = (r_version => 'string_datatype',
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

  my $inputFile = $self->getInputFileName();
  my $outputFile = $inputFile . ".out";

  my $isLogged = $self->getIsDataLogged();

  my $script =  $ENV{GUS_HOME} . "/bin/expressionProfileCalculations.r";

  unless(-e $script) {
    GUS::Community::RadAnalysis::ProcessorError->new("File [$script] does not exist")->throw();
  }

  my $command = "echo 'inputFile=\"$inputFile\"; outputFile=\"$outputFile\"' | cat - $script  | R --no-save";

  my $systemResult = system($command);

  unless($systemResult / 256 == 0) {
    GUS::Community::RadAnalysis::ProcessorError->new("Error while attempting to run R:\n$command")->throw();
  }

  return $outputFile;
}


#--------------------------------------------------------------------------------

sub writeFile {
  my ($self, $input, $logicalGroups) = @_;

  my @header;

  my $baseX = $self->getBaseX();

  my $fn = $self->getInputFileName();
  open(FILE, "> $fn") or die "Cannot open file [$fn] for writing: $!";

  my $name = $self->getInputName();

  foreach my $element (keys %$input) {
    my @output;

    if ($baseX) {
      push @output, map {$_ eq 'NA' ? 'NA' : $baseX ** $_} @{$input->{$element}->{$name}};
    }
    else {
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

1;
