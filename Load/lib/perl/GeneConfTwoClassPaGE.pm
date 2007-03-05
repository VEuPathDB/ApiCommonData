package ApiCommonData::Load::GeneConfTwoClassPaGE;
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

ApiCommonData::Load::GeneConfTwoClassPaGE;

=head1 SYNOPSIS

  my $args = {arrayDesignName => 'ARRAYDESIGN',
              ...
             };

  my $processer = ApiCommonData::Load::GeneConfTwoClassPaGE->new($args);
  my $results = $processer->process();

=head1 CONFIG ARGS

=over 4

=item C<arrayDesignName>

RAD::ArrayDesign name

=item C<quantificationUrisConditionA>

RAD::Quantification uris

=item C<quantificationUrisConditionB>

RAD::Quantification uris

=item C<analysisNamesConditionA>

 **Not yet implemented** (Analyses do not have names... must use analysisparam)

=item C<analysisNamesConditionB>

 **Not yet implemented** (Analyses do not have names... must use analysisparam)

=item C<studyName>

Study::Study Name

=item C<nameConditionA>

The name for the input (RAD::LogicalGroup)

=item C<nameConditionB>

The name for the input (RAD::LogicalGroup)

=item C<numberOfChannels>

Parameter for page (1 or 2)

=item C<isDataLogged>

Parameter for page (1 or 0)

=item C<isDataPaired>

Parameter for page (1 or 0)

=item C<pageInputFile>

How should the input file be named??

=item C<baseX>

If the data is logged... what base?

=item C<design>

If this is a 2 channel experiment  (R for Reference, D for DyeSwap)

=back

=head1 DESCRIPTION

Subclass of GUS::Community::RadAnalysis::AbstractProcessor which implements the process().
Query Database to create a PageInput file and then Run Page.

=head1 TODO

  -Get Data from Analysis Tables (2 channel Experiments)

=cut

my $RESULT_VIEW = 'RAD::DifferentialExpression';
my $XML_TRANSLATOR = 'unloggedPageGeneConf';
my $PAGE = 'PaGE_5.1.6_modifiedConfOutput.pl';
my $LEVEL_CONFIDENCE = 0.8;
my $MIN_PRESCENCE = 2;


#--------------------------------------------------------------------------------

sub new {
  my ($class, $argsHash) = @_;

  unless(ref($argsHash) eq 'HASH') {
    GUS::Community::RadAnalysis::InputError->new("Must provide a hashref to the constructor of TwoClassPage")->throw();
  }

  my $args = $argsHash;

  $args->{quantificationUrisConditionA} = [] unless($argsHash->{quantificationUrisConditionA});
  $args->{quantificationUrisConditionB} = [] unless($argsHash->{quantificationUrisConditionB});

  $args->{analysisNamesConditionA} = [] unless($argsHash->{analysisNamesConditionA});
  $args->{analysisNamesConditionB} = [] unless($argsHash->{analysisNamesConditionB});

  unless($args->{arrayDesignName}) {
    GUS::Community::RadAnalysis::InputError->new("Parameter [arrayDesignName] is missing in the config file")->throw();
  }

  unless($args->{studyName}) {
    GUS::Community::RadAnalysis::InputError->new("Parameter [studyName] is missing in the config file")->throw();
  }

  unless($args->{nameConditionA} && $args->{nameConditionB}) {
    GUS::Community::RadAnalysis::InputError->new("Parameters [nameConditionA] and [nameConditionB] are required in the config file")->throw();
  }

  unless($args->{numberOfChannels}) {
    GUS::Community::RadAnalysis::InputError->new("Parameter [numberOfChannels] is missing in the config file")->throw();
  }

  unless($args->{isDataLogged} == 1 || $args->{isDataLogged} == 0) {
    GUS::Community::RadAnalysis::InputError->new("Parameter [isDataLogged] is missing in the config file")->throw();
  }

  unless($args->{isDataPaired} == 1 || $args->{isDataPaired} == 0) {
    GUS::Community::RadAnalysis::InputError->new("Parameter [isDataPaired] is missing in the config file")->throw();
  }

  unless($args->{pageInputFile}) {
    GUS::Community::RadAnalysis::InputError->new("Parameter [pageInputFile] is missing in the config file")->throw();
  }

  if($args->{isDataLogged} && !$args->{baseX}) {
    GUS::Community::RadAnalysis::InputError->new("Parameter [baseX] must be given when specifying Data Is Logged")->throw();
  }

  if($args->{numberOfChannels} == 2 && ($args->{design} ne 'R' || $args->{design} ne 'D') ) {
    GUS::Community::RadAnalysis::InputError->new("Parameter [design] must be given (R|D) when specifying 2 channel data.")->throw();
  }

  bless $args, $class;
}

#--------------------------------------------------------------------------------

sub getArrayDesignName {$_[0]->{arrayDesignName}}
sub getStudyName {$_[0]->{studyName}}

sub getNameConditionA {$_[0]->{nameConditionA}}
sub getNameConditionB {$_[0]->{nameConditionB}}

sub getNumberOfChannels {$_[0]->{numberOfChannels}}
sub getIsDataLogged {$_[0]->{isDataLogged}}
sub getIsDataPaired {$_[0]->{isDataPaired}}
sub getDesign {$_[0]->{design}}

sub getQuantificationView {$_[0]->{quantificationView}}
sub getQuantificationUrisConditionA {$_[0]->{quantificationUrisConditionA}}
sub getQuantificationUrisConditionB {$_[0]->{quantificationUrisConditionB}}

sub getAnalysisView {$_[0]->{analysisView}}
sub getAnalysisNamesConditionA {$_[0]->{analysisNamesConditionA}}
sub getAnalysisNamesConditionB {$_[0]->{analysisNamesConditionB}}

sub getPageInputFile {$_[0]->{pageInputFile}}
sub getBaseX {$_[0]->{baseX}}

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

  my $pageMatrix = $self->createDataMatrixFromLogicalGroups($logicalGroups, $quantView, $analysisView, $dbh);

  $self->writePageInputFile($pageMatrix, $logicalGroups);

  # run page
  my $resultFile = $self->runPage();

  # make the Process Result
  my $result = GUS::Community::RadAnalysis::ProcessResult->new();

  $result->setArrayDesignName($arrayDesignName);
  $result->setArrayTable($arrayTable);
  $result->setResultFile($resultFile);
  $result->setResultView($RESULT_VIEW);
  $result->setXmlTranslator($XML_TRANSLATOR);

  my $translatorArgs = { numberOfChannels => $self->getNumberOfChannels(),
                         design => $self->getDesign(),
                       };

  $result->addToTranslatorFunctionArgs($translatorArgs);

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

  my $studyName = $self->getStudyName();

  my $conditionAName = $self->getNameConditionA();
  my $conditionBName = $self->getNameConditionB();

  my $aUris = $self->getQuantificationUrisConditionA();
  my $aAnalysisNames = $self->getAnalysisNamesConditionA();

  my $bUris = $self->getQuantificationUrisConditionB();
  my $bAnalysisNames = $self->getAnalysisNamesConditionB();

  if(scalar(@$aUris) > 0 && scalar(@$bUris) > 0) {
    my $logicalGroupA = $self->makeLogicalGroup($conditionAName, '', 'quantification', $aUris, $studyName, $dbh);
    my $logicalGroupB = $self->makeLogicalGroup($conditionBName, '', 'quantification', $bUris, $studyName, $dbh);

    push(@logicalGroups, $logicalGroupA);
    push(@logicalGroups, $logicalGroupB);
  }

  if(scalar(@$bAnalysisNames) > 0 && scalar(@$aAnalysisNames) > 0) {
    my $logicalGroupA = $self->makeLogicalGroup($conditionAName, '', 'analysis', $aAnalysisNames, $studyName, $dbh);
    my $logicalGroupB = $self->makeLogicalGroup($conditionBName, '', 'analysis', $bAnalysisNames, $studyName, $dbh);

    push(@logicalGroups, $logicalGroupA);
    push(@logicalGroups, $logicalGroupB);
  }

  return \@logicalGroups;
}



#--------------------------------------------------------------------------------

sub setupParamValues {
  my ($self) = @_;

  my $values = { level_confidence_list => $LEVEL_CONFIDENCE,
                 min_presence_list => $MIN_PRESCENCE,
                 data_is_logged => $self->getIsDataLogged(),
                 paired => $self->getIsDataPaired(),
                 use_logged_data => 'TRUE',
                 software_version => $PAGE,
                 software_language => 'perl',
                 num_channels => $self->getNumberOfChannels(),
                 reference_condition => $self->getNameConditionA(),
               };

  if(my $design = $self->getDesign()) {
    $values->{design} = $design;
  }

  return $values;
}



#--------------------------------------------------------------------------------

sub setupProtocol {
  my ($self) = @_;

  my $protocol = GUS::Model::RAD::Protocol->new({name => 'PaGE'});

  unless($protocol->retrieveFromDB) {
    $protocol->setUri('http://www.cbil.upenn.edu/PaGE');
    $protocol->setProtocolDescription('PaGE can be used to produce sets of differentially expressed genes with confidence measures attached. These lists are generated the False Discovery Rate method of controlling the false positives.  But PaGE is more than a differential expression analysis tool.  PaGE is a tool to attach descriptive, dependable, and easily interpretable expression patterns to genes across multiple conditions, each represented by a set of replicated array experiments.  The input consists of (replicated) intensities from a collection of array experiments from two or more conditions (or from a collection of direct comparisons on 2-channel arrays). The output consists of patterns, one for each row identifier in the data file. One condition is used as a reference to which the other types are compared. The length of a pattern equals the number of non-reference sample types. The symbols in the patterns are integers, where positive integers represent up-regulation as compared to the reference sample type and negative integers represent down-regulation. The patterns are based on the false discovery rates for each position in the pattern, so that the number of positive and negative symbols that appear in each position of the pattern is as descriptive as the data variability allows. The patterns generated are easily interpretable in that integers are used to represent different levels of up- or down-regulation as compared to the reference sample type.');

    $protocol->setSoftwareDescription('There are Perl and Java implementations.	');

    my $oe = GUS::Model::Study::OntologyEntry->new({value => 'differential_expression'});
    unless($oe->retrieveFromDB) {
      die "Cannot retrieve RAD::OntologyEntry [differential_expression]";
    }

    $protocol->setProtocolTypeId($oe->getId());
  }

  my $oeHash = $self->getOntologyEntries();

  $self->setupProtocolParams($protocol, $oeHash);
  $self->setupProtocolQCParams($protocol, $oeHash);

  return $protocol;
}


#--------------------------------------------------------------------------------

sub getOntologyEntries {
  my ($self) = @_;

  my %ontologyEntries;

  my @dataTypes = ('positive_integer',
                   'float',
                   'nonnegative_float',
                   'list_of_nonnegative_floats',
                   'string_datatype',
                   'list_of_positive_integers',
                   'boolean',
                   'list_of_floats',
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

sub setupProtocolQCParams {
  my ($self, $protocol, $oeHash) = @_;

  my %params = (lower_cutratio_list => 'list_of_floats',
                statistic_min_list => 'list_of_floats', 
                statistic_max_list => 'list_of_floats',
                upper_cutratio_list => 'list_of_floats',
                tstat_tuning_parameters_down => 'list_of_nonnegative_floats',
                tstat_tuning_parameters_up => 'list_of_nonnegative_floats',
               );

  my @protocolParams = $protocol->getChildren('RAD::ProtocolQCParam', 1);

  if(scalar(@protocolParams) == 0) {

    foreach(keys %params) {
      my $dataType = $params{$_};
      my $oe = $oeHash->{$dataType};

      my $oeId = $oe->getId();

      my $param = GUS::Model::RAD::ProtocolQCParam->new({name => $_,
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

sub setupProtocolParams {
  my ($self, $protocol, $oeHash) = @_;

  my %params = (tstat_tuning_parameter => 'nonnegative_float',
                level_confidence_list => 'list_of_nonnegative_floats', 
                min_presence_list => 'list_of_positive_integers',
                'shift' => 'float',
                data_is_logged => 'boolean',
                paired => 'boolean',
                use_logged_data => 'boolean',
                reference_condition => 'string_datatype',
                filtering_criterion => 'string_datatype',
                design => 'string_datatype',
                software_version => 'string_datatype',
                software_language => 'string_datatype',
                statistic => 'string_datatype',
                num_permutations => 'positive_integer',
                num_bins => 'positive_integer',
                num_channels => 'positive_integer',
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

sub runPage {
  my ($self) = @_;

  my $pageIn = $self->getPageInputFile();
  my $pageOut = $pageIn . ".out";

  my $channels = $self->getNumberOfChannels();
  my $isLogged = $self->getIsDataLogged();
  my $isPaired = $self->getIsDataPaired();

  my $isLoggedArg = $isLogged ? "--data_is_logged" : "--data_not_logged";
  my $isPairedArg = $isPaired ? "--paired" : "--unpaired";

  my $pageCommand = "$PAGE --infile $pageIn --outfile $pageOut --output_gene_confidence_list --output_text --num_channels $channels $isLoggedArg $isPairedArg --level_confidence $LEVEL_CONFIDENCE --use_logged_data --tstat --min_presence $MIN_PRESCENCE --missing_value NA";

  my $systemResult = system($pageCommand);

  unless($systemResult / 256 == 0) {
    GUS::Community::RadAnalysis::ProcessorError->new("Error while attempting to run PaGE:\n$pageCommand")->throw();
  }

  my $geneConfList = $pageOut . "-gene_conf_list.txt";

  return $geneConfList;
}


#--------------------------------------------------------------------------------

sub writePageInputFile {
  my ($self, $input, $logicalGroups) = @_;

  my @header;

  my $baseX = $self->getBaseX();

  my $pageIn = $self->getPageInputFile();
  open(PAGE, "> $pageIn") or die "Cannot open file [$pageIn] for writing: $!";

  my $conditionAName = $self->getNameConditionA();
  my $conditionBName = $self->getNameConditionB();

  my $conditionACount;
  my $conditionBCount;

  foreach my $lg (@$logicalGroups) {
    foreach my $link ($lg->getChildren('RAD::LogicalGroupLink')) {
      $conditionACount++ if($lg->getName eq $conditionAName);
      $conditionBCount++ if($lg->getName eq $conditionBName);
    }
  }

  push @header, @{$self->pageHeader('c0r', $conditionACount)};
  push @header, @{$self->pageHeader('c1r', $conditionBCount)};


  print PAGE join("\t", "id", @header) . "\n";

  foreach my $element (keys %$input) {
    my @output;


    if ($baseX) {
      push @output, map {$_ eq 'NA' ? 'NA' : $baseX ** $_} @{$input->{$element}->{$conditionAName}};
      push @output, map {$_ eq 'NA' ? 'NA' : $baseX ** $_} @{$input->{$element}->{$conditionBName}};
    }
    else {
      push @output, @{$input->{$element}->{$conditionAName}};
      push @output, @{$input->{$element}->{$conditionBName}};
    }

    my $naCount;
    map {$naCount++ if($_ eq 'NA')} @output;

    # Don't print if they are all NA's
    unless(scalar(@output) == $naCount) {
      print PAGE join("\t", $element, @output) . "\n";
    }
  }
  close PAGE;
}

#--------------------------------------------------------------------------------

sub pageHeader {
  my ($self, $prefix, $n) = @_;

  my @values;

  foreach my $i (1..$n) {
    my $value = $prefix . $i;
    push(@values, $value);
  }
  return \@values;
}

#--------------------------------------------------------------------------------

1;
