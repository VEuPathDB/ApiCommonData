package ApiCommonData::Load::GeneConfTwoClassPaGE;
use base qw(GUS::Community::RadAnalysis::AbstractProcesser);

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

Subclass of GUS::Community::RadAnalysis::AbstractProcesser which implements the process().
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
    GUS::Community::RadAnalysis::ProcesserError->new("Package [UserProvidedNorm] Requires Default DbiDatabase")->throw();
  }

  my $dbh = $database->getQueryHandle();

  my $logicalGroups = $self->setupLogicalGroups($dbh);

  # Get all the elements for an ArrayDesign
  my $arrayDesignName = $self->getArrayDesignName();
  my $arrayTable = $self->queryForArrayTable($dbh, $arrayDesignName);
  my $allElements = $self->queryForElements($dbh, $arrayTable, $arrayDesignName);

  # make the page Input file
  my ($header, $pageMatrix) = $self->preparePageInput($dbh, $allElements, $arrayTable);
  $self->writePageInputFile($header, $pageMatrix);

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

  my $conditionAName = $self->getNameConditionA();
  my $conditionBName = $self->getNameConditionB();

  my $logicalGroupA = GUS::Model::RAD::LogicalGroup->new({name => $conditionAName});
  my $logicalGroupB = GUS::Model::RAD::LogicalGroup->new({name => $conditionBName});

  unless($logicalGroupA->retrieveFromDB) {
    my $aUris = $self->getQuantificationUrisConditionA();
    my $aAnalysisNames = $self->getAnalysisNamesConditionA();

    $self->setupLinks($logicalGroupA, $aUris, 'quantification', $dbh) if(scalar(@$aUris) > 0);
    $self->setupLinks($logicalGroupA, $aAnalysisNames, 'analysis', $dbh) if(scalar(@$aAnalysisNames) > 0);
  }

  unless($logicalGroupB->retrieveFromDB) {
    my $bUris = $self->getQuantificationUrisConditionB();
    my $bAnalysisNames = $self->getAnalysisNamesConditionB();

    $self->setupLinks($logicalGroupB, $bUris, 'quantification', $dbh)  if(scalar(@$bUris) > 0);
    $self->setupLinks($logicalGroupB, $bAnalysisNames, 'analysis', $dbh) if(scalar(@$bAnalysisNames) > 0);
  }

  return [$logicalGroupA, $logicalGroupB];
}

#--------------------------------------------------------------------------------

sub setupLinks {
  my ($self, $lg, $names, $type, $dbh) = @_;

  my $studyName = $self->getStudyName();
  my $coreHash = $self->queryForTable($dbh);

  my %allSql = (quantification => <<Sql,
select quantification_id
from Rad.QUANTIFICATION q, Rad.ACQUISITION a,
     Rad.STUDYASSAY sa, Study.Study s
where q.acquisition_id = a.acquisition_id
 and a.assay_id = sa.assay_id
 and sa.study_id = s.study_id
 and s.name = ?
 and q.uri = ?
Sql
                analysis => <<Sql,
Sql
                );

  my $sql = $allSql{$type};
  my $sh = $dbh->prepare($sql);

  my @links;
  my $orderNum = 1;

  foreach(@$names) {
    $sh->execute($studyName, $_);

    my ($quantId) = $sh->fetchrow_array();
    $sh->finish();

    unless($quantId) {
      GUS::Community::RadAnalysis::SqlError->new("Could not retrieve quantification for [$_]")->throw();
    }

    my $link = GUS::Model::RAD::LogicalGroupLink->new({order_num => $orderNum,
                                                       table_id => $coreHash->{$type},
                                                       row_id => $quantId,
                                                      });
    $link->setParent($lg);

    $orderNum++;
  }

  return \@links;
}

#--------------------------------------------------------------------------------

sub queryForTable {
  my ($self, $dbh) = @_;

  my %rv;

  my $sql = "select lower(t.name), t.table_id from Core.TableInfo t, Core.DATABASEINFO d
             where t.database_id = d.database_id
              and d.name = 'RAD'
              and t.name in ('Quantification', 'Analysis')";

  my $sh = $dbh->prepare($sql);
  $sh->execute();

  while(my ($name, $id) = $sh->fetchrow_array()) {
    $rv{$name} = $id;
  }
  $sh->finish();

  return \%rv;
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
    GUS::Community::RadAnalysis::ProcesserError->new("Error while attempting to run PaGE:\n$pageCommand")->throw();
  }

  my $geneConfList = $pageOut . "-gene_conf_list.txt";

  return $geneConfList;
}


#--------------------------------------------------------------------------------

sub writePageInputFile {
  my ($self, $header, $input) = @_;

  my $pageIn = $self->getPageInputFile();
  open(PAGE, "> $pageIn") or die "Cannot open file [$pageIn] for writing: $!";

  print PAGE join("\t", "id", @$header) . "\n";

  foreach(keys %$input) {
    print PAGE join("\t", $_, @{$input->{$_}}) . "\n";
  }
}

#--------------------------------------------------------------------------------

sub preparePageInput {
  my ($self, $dbh, $allElements, $arrayTable) = @_;

  my %pageInput;

  my $baseX = $self->getBaseX();

  my $aUris = $self->getQuantificationUrisConditionA();
  my $bUris = $self->getQuantificationUrisConditionB();

  my $aAnalysisNames = $self->getAnalysisNamesConditionA();
  my $bAnalysisNames = $self->getAnalysisNamesConditionB();

  my $headers = $self->makeHeader($aUris, $bUris, $aAnalysisNames, $bAnalysisNames);

  my $quantShA = $self->getQuantificationSqlHandle($aUris, $dbh);
  my $quantShB = $self->getQuantificationSqlHandle($bUris, $dbh);

  # TODO:  getAnalysisSqlHandle (A and B)

  foreach my $element (@$allElements) {
    if(my $quantView = $self->getQuantificationView()) {
      my $conditionAValues = $self->getQuantificationValues($element, $quantShA, $aUris, $baseX);
      my $conditionBValues = $self->getQuantificationValues($element, $quantShB, $bUris, $baseX);

      push(@{$pageInput{$element}}, @$conditionAValues, @$conditionBValues);
    }

    # TODO:  This Bit is not yet implemented!!!
    if(my $analysisView = $self->getAnalysisView()) {
      my $conditionAValues = $self->getAnalysisValues();
      my $conditionBValues = $self->getAnalysisValues();

      push(@{$pageInput{$element}}, @$conditionAValues, @$conditionBValues);
    }
  }
  return($headers, \%pageInput);
}

#--------------------------------------------------------------------------------

sub getQuantificationSqlHandle {
  my ($self, $uris, $dbh) = @_;

  my $uriString = join(',', map { "'$_'" } @$uris);

  my $view = $self->getQuantificationView();
  return unless($view);

  # add to this for other views of CompositeElementResultImp
  my %quantSql = ('RMAExpress' => <<Sql,
select q.uri, e.rma_expression_measure
from Rad.QUANTIFICATION q,
     Rad.ACQUISITION a, Rad.STUDYASSAY sa, Study.Study s,
     Rad.RMAEXPRESS e, RAD.SHORTOLIGOFAMILY spot 
where e.quantification_id = q.quantification_id
 and spot.composite_element_id = e.composite_element_id 
 and q.acquisition_id = a.acquisition_id
 and a.assay_id = sa.assay_id
 and sa.study_id = s.study_id
 and q.uri in ($uriString)
 and s.name = ?
 and spot.composite_element_id = ?
Sql
               );

  my $sql = $quantSql{$view};

  return $dbh->prepare($sql);
}


#--------------------------------------------------------------------------------

sub getAnalysisValues {
  die "Query For analysis table is not yet implemented";
}

#--------------------------------------------------------------------------------

sub getQuantificationValues {
  my ($self, $element, $sh, $uris, $baseX) = @_;

  my @rv;

  my $studyName = $self->getStudyName();

  $sh->execute($studyName, $element);

  my %values;

  while(my ($uri, $value) = $sh->fetchrow_array()) {
    $values{$uri} = $value;
  }
  $sh->finish();

  # make sure the order is always the same
  # add 'NA' for those with potential missing values

  foreach my $uri (@$uris) {

    if($baseX && $values{$uri}) {
      $values{$uri} = $baseX ** $values{$uri};
    }

    unless($values{$uri}) {
      $values{$uri} = 'NA';
    }

    push(@rv, $values{$uri});
  }

  return \@rv;
}


#--------------------------------------------------------------------------------

sub makeHeader {
  my ($self, $au, $bu, $aa, $ba) = @_;

  my @header;

  push(@header, @{$self->pageHeader('c0r', scalar(@$au))});
  push(@header, @{$self->pageHeader('c1r', scalar(@$bu))});

  push(@header, @{$self->pageHeader('c0r', scalar(@$aa))});
  push(@header, @{$self->pageHeader('c1r', scalar(@$ba))});

  return \@header;
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

sub queryForElements {
  my ($self, $dbh, $arrayTable, $arrayDesignName) = @_;

  my %allSql = ('RAD.ShortOligoFamily' => <<Sql,
select composite_element_id 
from $arrayTable e, Rad.ARRAYDESIGN a
where a.array_design_id = e.array_design_id
 and a.name = ?
Sql
                'RAD.Spot' => <<Sql,
select element_id 
from $arrayTable e, Rad.ARRAYDESIGN a
where a.array_design_id = e.array_design_id
 and a.name = ?
Sql
                );

  my $sql = $allSql{$arrayTable};

  my $sh = $dbh->prepare($sql);
  $sh->execute($arrayDesignName);

  my @elementIds;

  while(my ($elementId) = $sh->fetchrow_array()) {
    push(@elementIds, $elementId);
  }
  $sh->finish();

  return \@elementIds;
}

#--------------------------------------------------------------------------------

sub queryForArrayTable {
  my ($self, $dbh, $arrayDesignName) = @_;

  my $sql = <<Sql;
select oe.value
from study.ontologyentry oe, Rad.ARRAYDESIGN a
where a.technology_type_id = oe.ontology_entry_id
and a.name = ?
Sql

  my $sh = $dbh->prepare($sql);
  $sh->execute($arrayDesignName);  

  my ($type) = $sh->fetchrow_array();
  $sh->finish();

  if($type eq 'in_situ_oligo_features') {
    return 'RAD.ShortOligoFamily';
  }

  return 'RAD.Spot';
}

#--------------------------------------------------------------------------------

1;
