##
#vvvvvvvvvvvvvvvvvvvvvvvvv GUS4_STATUS vvvvvvvvvvvvvvvvvvvvvvvvv
  # GUS4_STATUS | SRes.OntologyTerm              | auto   | absent
  # GUS4_STATUS | SRes.SequenceOntology          | auto   | absent
  # GUS4_STATUS | Study.OntologyEntry            | auto   | broken
  # GUS4_STATUS | SRes.GOTerm                    | auto   | absent
  # GUS4_STATUS | Dots.RNAFeatureExon            | auto   | absent
  # GUS4_STATUS | RAD.SageTag                    | auto   | broken
  # GUS4_STATUS | RAD.Analysis                   | auto   | broken
  # GUS4_STATUS | ApiDB.Profile                  | auto   | absent
  # GUS4_STATUS | Study.Study                    | auto   | absent
  # GUS4_STATUS | Dots.Isolate                   | auto   | absent
  # GUS4_STATUS | DeprecatedTables               | auto   | broken
  # GUS4_STATUS | Pathway                        | auto   | absent
  # GUS4_STATUS | DoTS.SequenceVariation         | auto   | absent
  # GUS4_STATUS | RNASeq Junctions               | auto   | absent
  # GUS4_STATUS | Simple Rename                  | auto   | absent
  # GUS4_STATUS | ApiDB Tuning Gene              | auto   | absent
  # GUS4_STATUS | Rethink                        | auto   | absent
  # GUS4_STATUS | dots.gene                      | manual | unreviewed
die 'This file has broken or unreviewed GUS4_STATUS rules.  Please remove this line when all are fixed or absent';
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^
## InsertRadAnalysis Plugin
## $Id: InsertRadAnalysis.pm 5815 2007-11-21 18:28:23Z manduchi $
##

package ApiCommonData::Load::Plugin::InsertRadAnalysis;
@ISA = qw( GUS::PluginMgr::Plugin );

use strict;
use IO::File;
use CBIL::Util::Disp;
use GUS::PluginMgr::Plugin;

use GUS::Model::RAD::Analysis;
use GUS::Model::SRes::Contact;
use GUS::Model::RAD::Protocol;
use GUS::Model::Study::OntologyEntry;
use GUS::Model::RAD::AssayAnalysis;
use GUS::Model::RAD::AnalysisParam;
use GUS::Model::RAD::ProtocolParam;
use GUS::Model::RAD::AnalysisQCParam;
use GUS::Model::RAD::ProtocolQCParam;
use GUS::Model::RAD::LogicalGroup;
use GUS::Model::RAD::AnalysisInput;
use GUS::Model::Core::TableInfo;
use GUS::Model::Core::DatabaseInfo;

# ----------------------------------------------------------------------
# Arguments
# ---------------------------------------------------------------------

sub getArgumentsDeclaration {
  my $argumentDeclaration  =
    [
     tableNameArg({name => 'subclass_view',
		   descr => 'The name of the view of RAD.AnalysisResultImp in which the results of the analysis should be loaded. Format should be RAD::viewname.',
	           constraintFunc=> undef,
		   reqd => 1,
		   isList => 0
		  }),

   fileArg({name           => 'configFile',
	    descr          => 'Describes the profiles being loaded',
	    reqd           => 1,
	    mustExist      => 1,
	    format         => 'Tab file with no header and these columns: cfg_file, data_file.',
	    constraintFunc => undef,
	    isList         => 0, }),


     integerArg({name  => 'restart',
		 descr => 'Line number in data_file from which loading should be resumed (line 1 is the first line after the header, empty lines are counted). If this argument is given the analysis_id should also be given.',
		 constraintFunc=> undef,
		 reqd  => 0,
		 isList => 0
		}),
     integerArg({name  => 'analysis_id',
		 descr => 'The analysis_id of the analysis whose results loading should be resumed with the --restart option. This argument should be provided if and only if the restart option is used.',
		 constraintFunc=> undef,
		 reqd  => 0,
		 isList => 0
		}),
     integerArg({name  => 'testnum',
		 descr => 'The number of data lines to read when testing this plugin. Not to be used in commit mode.',
		 constraintFunc=> undef,
		 reqd  => 0,
		 isList => 0
		}),
     booleanArg({ name  => 'orderInput',
		  descr => 'If true, RAD.AnalysisInput.order_num will be populated',
		  constraintFunc => undef,
		  reqd           => 0,
		  isList         => 0 })
    ];
  return $argumentDeclaration;
}

# ----------------------------------------------------------------------
# Documentation
# ----------------------------------------------------------------------

sub getDocumentation {
  my $purposeBrief = 'Loads inputs, parameter settings, and results of gene expression data analyses (pre-processing or down-stream) into the appropriate group of RAD tables.';

  my $purpose = "This plugin reads a configuration file and a data file (representing the results of some gene expression data pre-processing or down-stream analysis) and inserts inputs, parameter settings, and results into the appropriate tables in RAD.";

  my $tablesAffected = [['RAD::Analysis', 'Enters a row representing this analysis here'], ['RAD::AssayAnalysis', 'Enters rows here linking this analysis to all relevant assays, if the LogicalGroups input into the analysis consists of quantifications, or acquisitions, or assays'], ['RAD::AnalysisParam', 'Enters the values of the protocol parameters for this analysis here'], ['RAD::AnalysisQCParam', 'Enters the values of the protocol quality control parameters for this analysis here'], ['RAD::AnalysisInput', 'Enters the input(s) of this analysis here'], ['RAD::AnalysisResultImp', 'Enters the results of this analysis here']];

  my $tablesDependedOn = [['SRes::Contact', 'The researcher or organization who performed this analysis'], ['RAD::Protocol', 'The analysis protocol used'], ['RAD::ProtocolStep', 'The components of the analysis protocol used, if the latter is an ordered series of protocols'], ['Study::OntologyEntry', 'The protocol_type of the protocol used'], ['RAD::ProtocolParam', 'The parameters for the protocol used or for its components'], ['RAD::ProtocolQCParam', 'The quality control parameters for the protocol used or for its components'], ['RAD::LogicalGroup', 'The input group(s) to the analysis'], ['RAD::LogicalGroupLink', 'The members of the logical group(s) input into the analysis'],['Core::TableInfo', 'The table whose entries the analysis results refer to'], ['Core::DatabaseInfo', 'The name of the GUS space containing the table whose entries the analysis results refer to']]; 

  my $howToRestart = "Loading can be resumed using the I<--restart n> argument where n is the line number in the data file of the first row to load upon restarting (line 1 is the first line after the header, empty lines are counted). If this argument is given then the I<analysis_id> argument should be given too. Alternatively, one can use the plugin GUS::Community::Plugin::Undo to delete all entries inserted by a specific call to this plugin. Then this plugin can be re-run from fresh.";

  my $failureCases = "";

  my $notes = <<NOTES;

=head2 F<cfg_file>

This should be a tab-delimited text file with 2 columns: I<name> and I<value>.
The names should be spelled exactly as described below. The order of the rows is not important.

See the sample config file F<sample_AnalysisResultLoader.cfg> in the GUS/RAD/config directory.

Empty lines are ignored.

Each (non-empty) line should contain B<exactly one> tab.

Do not use special symbols (like NA or similar) for empty fields: either leave the field empty or delete the entire line.

The names of each field and instructions for their values are as follows:

B<I<analysis_name>>

A name which will identify this analysis.

B<I<table>> [Mandatory]

The table (or view) whose entries the analysis results refer to. The format should be I<space.name>, e.g. RAD.SpotFamily. Both I<space> and I<name> must be spelled B<exactly> (case sensitive) as spelled in Core.DatabaseInfo.name and Core.TableInfo.name.

B<I<operator_id>>

The contact_id (in SRes.Contact) of the researcher or organization who performed this analysis.

B<I<protocol_id>> [Mandatory]

The protocol_id (in RAD.Protocol) of the protocol for this analysis. If I<--subclass_view> is RAD::DataTransformationResult, then the type of this protocol should be in the DataTransformationProtocolType category. In all other cases, it should be in the HigherLevelAnalysisProtocolType category.

B<I<analysis_date>>

The date when the specific analysis was performed. The correct format is YYYY-MM-DD.

B<I<protocol_param_idN>>

The protocol_parameter_id (in RAD.ProtocolParam) of the I<N>th parameter whose value is being assigned (possibly overwriting a specified default value). Start with I<N>=1, for the first parameter you want to set, and continue up to the number of parameters you want to set.

B<I<protocol_param_valueN>>

The value to be assigned to the I<N>th parameter, whose id is specified by I<protocol_param_idN>.

B<I<protocol_qc_param_idN>>

The protocol_qc_parameter_id (in RAD.ProtocolQCParam) of the I<N>th quality control parameter whose value is being assigned (possibly overwriting a specified default value). Start with I<N>=1, for the first qc parameter you want to set, and continue up to the number of qc parameters you want to set.

B<I<protocol_qc_param_valueN>>

The value to be assigned to the I<N>th quality control parameter, whose id is specified by I<protocol_qc_param_idN>.

B<I<logical_group_idN>>

The logical_group_id (in RAD.LogicalGroup) of the I<N>th input group to this analysis. Start with I<N>=0  (e.g. in PaGE) or 1, for the first input group, and continue till you have exhausted all input groups. B<At least one> logical group id should be provided. If --orderInput is true, I<N> will be used to populate RAD.AnalysisInput.order_num for that logical group.

=head2 F<data_file>

The data file should be in tab-delimited text format with one header line and a line for each result to be entered in the appropriate view of AnalysisResultImp.
All lines should contain the same number of tab/fields. Empty lines will be ignored.

The header should contain a field called I<row_id>, to hold the primary keys
(in the table I<table>, given in the F<cfg_file>), for the entries the results refer to.

The other fields should have B<lower case> names spelled B<exactly> as the field names in the view specified by the I<--subclass_view> argument.

The fields I<subclass_view>, I<analysis_id>, and I<table_id> do not have to be specified in the F<data_file>, as this plugin derives their values from its arguments (including the F<cfg_file>).

Missing values in a field can be left empty or set to na or NA or n/a or N/A. If all (non row_id) values for a row are missing, that row is not entered.

=head1 AUTHOR

Written by Elisabetta Manduchi.

=head1 COPYRIGHT

Copyright Elisabetta Manduchi, Trustees of University of Pennsylvania 2003. 
NOTES

  my $documentation = {purpose=>$purpose, purposeBrief=>$purposeBrief, tablesAffected=>$tablesAffected, tablesDependedOn=>$tablesDependedOn, howToRestart=>$howToRestart, failureCases=>$failureCases, notes=>$notes};

  return $documentation;
}

# ----------------------------------------------------------------------
# create and initalize new plugin instance.
# ----------------------------------------------------------------------

sub new {
  my ($class) = @_;
  my $self = {};
  bless($self,$class);

  my $documentation = &getDocumentation();
  my $argumentDeclaration    = &getArgumentsDeclaration();

  $self->initialize({requiredDbVersion => 3.6,
		     cvsRevision => '$Revision$',
		     name => ref($self),
		     revisionNotes => '',
		     argsDeclaration => $argumentDeclaration,
		     documentation => $documentation
		    });
  return $self;
}

# ----------------------------------------------------------------------
# run method to do the work
# ----------------------------------------------------------------------

sub run {
  my ($self) = @_;

  $self->logAlgInvocationId();
  $self->logCommit();
  $self->logArgs();
  $self->checkArgs();
  $self->readConfigFile();

  my @configFiles = @{$self->{configFile}};
  my $resultDescrip = "";
  for (my $i=0; $i<scalar(@configFiles); $i++) {
      my ($cfg_file,$data_file)=split(/\t/,$configFiles[$i]);
      my $cfgInfo = $self->readCfgFile($cfg_file);
      my $sv = $self->getArg('subclass_view');
      my $view = "GUS::Model::$sv";
      eval "require $view";
      my ($data, $lineCount) = $self->readDataFile($view, $cfgInfo->{'pk'}, $cfgInfo->{'table'},$data_file);
      $self->logData("There are $lineCount lines in data_file $data_file after the header, counting empty lines.");

      my $analysisId;

      if (defined $self->getArg('analysis_id')) {
	  $analysisId = $self->getArg('analysis_id');
      }
      else {
	  ($resultDescrip, $analysisId) = $self->insertAnalysis($cfgInfo);
      }
      $self->setResultDescr($resultDescrip);

      $resultDescrip .= " ". $self->insertAnalysisResults($view, $analysisId, $cfgInfo->{'table_id'}, $data, $lineCount);

      $self->setResultDescr($resultDescrip);
      $self->logData($resultDescrip);
  }
}

# ----------------------------------------------------------------------
# methods called by run
# ----------------------------------------------------------------------

sub checkArgs {
  my ($self) = @_;

  my $dbh = $self->getQueryHandle();
  my $sth = $dbh->prepare("select t.table_id from Core.TableInfo t, Core.DatabaseInfo d where t.name='AnalysisResultImp' and d.name='RAD' and t.database_id=d.database_id");
  $sth->execute();
  my ($id) = $sth->fetchrow_array();

  my ($space, $name) = split(/::/, $self->getArg('subclass_view'));
  if ($space eq "RAD") {
    my $table = GUS::Model::Core::TableInfo->new({name => $name, is_view => 1, view_on_table_id => $id});
    if (!$table->retrieveFromDB()) {
      $self->userError("$space\:\:$name is not a valid view of RAD.AnalysisResultImp.");
    }
  }
  else {
    $self->userError("The format for --subclass_view should be RAD::viewname.");
  }

  if (defined($self->getArg('testnum')) && $self->getArg('commit')) {
    $self->userError("The --testnum argument can only be provided if COMMIT is OFF.");
  }
  if (!defined($self->getArg('restart')) && defined($self->getArg('analysis_id'))) {
    $self->userError('The --restart argument must be provided only if the --analysis_id argument is provided.');
  }
  if (!defined($self->getArg('analysis_id')) && defined($self->getArg('restart'))) {
    $self->userError('The --analysis_id argument must be provided only if the --restart argument is provided.');
  }
  if (defined($self->getArg('restart')) && $self->getArg('restart')<1) {
    $self->userError('The value of the --restart argument should be an integer greater than or equal to 1.');
  }
  if (defined($self->getArg('testnum')) && $self->getArg('testnum')<1) {
    $self->userError('The value of the --testnum argument should be an integer greater than or equal to 1.');
  }
  if (defined($self->getArg('analysis_id'))) {
    my $analysis = GUS::Model::RAD::Analysis->new({'analysis_id' => $self->getArg('analysis_id')});
    if (!$analysis->retrieveFromDB()) {
      $self->userError('Invalid analysis_id.');
    }
  }
}


sub readConfigFile {
  my ($self) = @_;

  open(CONFIG_FILE, $self->getArg('configFile'));
  while (<CONFIG_FILE>) {
    chomp;
    my @vals = split(/\t/, $_);
    scalar(@vals) == 2
      || $self->userError("Config file has invalid line: '$_'");

    my $configFile=$vals[0]."\t".$vals[1];
    push(@{$self->{configFile}}, $configFile);
  }
}

sub readCfgFile {
  my ($self,$cfg_file) = @_;
  my $cfgInfo;

  my $dbh = $self->getQueryHandle();
  my $fh = new IO::File;
  unless ($fh->open("<$cfg_file")) {
    $self->error("Could not open file $cfg_file.");
  }
  my $analysisNameGiven = 0;
  my $tableGiven = 0;
  my $operatorIdGiven = 0;
  my $protocolIdGiven = 0;
  my $analysisDateGiven = 0;
  my $logicalGroupIdGiven = 0;

  while (my $line=<$fh>) {
    my ($name, $value) = split(/\t/, $line);
    $name =~ s/^\s+|\s+$//g;
    $value =~ s/^\s+|\s+$//g;
    if ($name ne '' && $value ne '') {
      if ($name eq 'analysis_name') {
	if (!$analysisNameGiven) {
	  $cfgInfo->{'analysis_name'} = $value;
	  $analysisNameGiven = 1;
	}
	else {
	  $self->userError('Only one analysis_name should be provided in the cfg_file.');
	}
      }
      elsif ($name eq 'table') {
	if (!$tableGiven) {
	  my ($space, $tablename) = split(/\./, $value);
	  my $db = GUS::Model::Core::DatabaseInfo->new({'name' =>$space});
	  if (!$db->retrieveFromDB()) {
	    $self->userError("The space name $space, provided in the cfg_file for the table field, is not a valid name in Core.DatabaseInfo.");
	  }
	  else {
	    my $dbId = $db->getId();
	    my $table = GUS::Model::Core::TableInfo->new({'name' =>$tablename, 'database_id' => $dbId});
	    if (!$table->retrieveFromDB()) {
	      $self->userError("The table name $tablename with database $space, as provided in the cfg_file for the table field, is not a valid entry in Core.TableInfo.");
	    }
	    else {
	      $cfgInfo->{'table_id'} = $table->getId();
	      $cfgInfo->{'pk'} = $table->get('primary_key_column');
	      $cfgInfo->{'table'} = $value;
	      $tableGiven = 1;
	    }
	  }
	}
	else {
	  $self->userError('Only one table should be provided in the cfg_file.');
	}
      }
      elsif ($name eq 'operator_id') {
	if (!$operatorIdGiven) {
	  my $contact = GUS::Model::SRes::Contact->new({'contact_id' =>$value});
	  if (!$contact->retrieveFromDB()) {
	    $self->userError("operator_id $value, provided in the cfg_file, is not a valid contact_id.");
	  }
	  $cfgInfo->{'operator_id'} = $value;
	  $operatorIdGiven = 1;
	}
	else {
	  $self->userError('Only one operator_id should be provided in the cfg_file.');
	}
      }
      elsif ($name eq 'protocol_id') {
	if (!$protocolIdGiven) {
	  my $protocol = GUS::Model::RAD::Protocol->new({'protocol_id' =>$value});
	  if (!$protocol->retrieveFromDB()) {
	    $self->userError("protocol_id $value, provided in the cfg_file, is not a valid protocol_id.");
	  }
	  my $oeId = $protocol->get('protocol_type_id');
	  my $oe = GUS::Model::Study::OntologyEntry->new({'ontology_entry_id' =>$oeId});
	  $oe->retrieveFromDB();
	  if ($self->getArg('subclass_view') eq 'RAD::DataTransformationResult' && $oe->get('category') ne 'DataTransformationProtocolType') {
	    $self->log("WARNING:  You are trying to load into the view RAD::DataTransformationResult, but the protocol type for the protocol_id provided in the cfg_file is not in the DataTransformationProtocolType category.");
	  }
	  if ($self->getArg('subclass_view') ne 'RAD::DataTransformationResult' && $oe->get('category') ne 'HigherLevelAnalysisProtocolType') {
	    $self->log("WARNING:  The protocol type for the protocol_id provided in the cfg_file is not in the HigherLevelAnalysisProtocolType category.");
	  }
	  $cfgInfo->{'protocol_id'} = $value;
	  $protocolIdGiven = 1;
	}
	else {
	  $self->userError('Only one protocol_id should be provided in the cfg_file.');
	}
      }
      elsif ($name eq 'analysis_date') {
	if (!$analysisDateGiven) {
	  if ($value =~ /^(\d\d\d\d)\-(\d\d)\-(\d\d)$/) {
	    $cfgInfo->{'analysis_date'} = $value.' 00:00:00'; 
	    $analysisDateGiven = 1;
	  } 
	  else {
	    $self->userError("Invalid date format for analysis_date in the cfg_file. The correct format is YYYY-MM-DD.");
	  }
	}
	else {
	  $self->userError('Only one analysis_date should be provided in the cfg_file.');
	}
      }
      elsif ($name =~ /^protocol_param_id(\d+)$/) {
	my $index = $1;
	if ($index<1) {
	  $self->userError('In the cfg_file, each protocol_param_idN must have N>0.');
	}
	$cfgInfo->{'protocol_param_id'}->[$index] = $value;
      }
      elsif ($name =~ /^protocol_param_value(\d+)$/) {
	my $index = $1;
	if ($index<1) {
	  $self->userError('In the cfg_file, each protocol_param_valueN must have N>0.');
	}
	$cfgInfo->{'protocol_param_value'}->[$index] = $value;
      }
      elsif ($name =~ /^protocol_qc_param_id(\d+)$/) {
	my $index = $1;
	if ($index<1) {
	  $self->userError('In the cfg_file, each protocol_qc_param_idN must have N>0.');
	}
	$cfgInfo->{'protocol_qc_param_id'}->[$index] = $value;
      }
      elsif ($name =~ /^protocol_qc_param_value(\d+)$/) {
	my $index = $1;
	if ($index<1) {
	  $self->userError('In the cfg_file, each protocol_qc_param_valueN must have N>0.');
	}
	$cfgInfo->{'protocol_qc_param_value'}->[$index] = $value;
      }
      elsif ($name =~ /^logical_group_id(\d+)$/) {
	my $index = $1;
	if ($index<0) {
	  $self->userError('In the cfg_file, each logical_group_idN must have N>=0.');
	}
	my $group = GUS::Model::RAD::LogicalGroup->new({'logical_group_id' => $value});
	if (!$group->retrieveFromDB()) {
	  $self->userError("logical_group_id $value, provided in the cfg_file, is not a valid logical_group_id.");
	}
	$cfgInfo->{'logical_group_id'}->[$index] = $value;
	$logicalGroupIdGiven++;
      }
      else {
	$self->userError('The only valid names in the cfg_file are: analysis_name, table, operator_id, protocol_id, analysis_date, protocol_param_idN, protocol_param_valueN, protocol_qc_param_idN, protocol_qc_param_valueN, logical_group_idN.');
      }
    }
  }
  $fh->close();
  if (!$tableGiven) {
    $self->userError->('The cfg_file must contain a value for table.');
  }
  if (!defined($self->getArg('analysis_id')) && (!$protocolIdGiven || !$logicalGroupIdGiven)) {
    $self->userError('The cfg_file must contain values for protocol_id and at least one logical_group_id.');
  }
  if (defined($cfgInfo->{'protocol_param_id'}) && defined($cfgInfo->{'protocol_param_value'}) && scalar(@{$cfgInfo->{'protocol_param_id'}}) != scalar(@{$cfgInfo->{'protocol_param_value'}})) {
    $self->userError("The number or protocol_param_id's given in the cfg_file does not match the number of protocol_param_value's.");
  }
  if (defined($cfgInfo->{'protocol_qc_param_id'}) && defined($cfgInfo->{'protocol_qc_param_value'}) && scalar(@{$cfgInfo->{'protocol_qc_param_id'}}) != scalar(@{$cfgInfo->{'protocol_qc_param_value'}})) {
    $self->userError("The number or protocol_qc_param_id's given in the cfg_file does not match the number of protocol_qc_param_value's.");
  }
  if (defined($cfgInfo->{'protocol_param_id'})) {
     my $sth1 = $dbh->prepare("select o.category, o.value from Study.OntologyEntry o, RAD.Protocol p where p.protocol_type_id=o.ontology_entry_id and p.protocol_id=$cfgInfo->{'protocol_id'}");
    $sth1->execute();
    my ($category, $protocolType) = $sth1->fetchrow_array();
    my @protocolIds = ($cfgInfo->{'protocol_id'});
    if ($category eq "DataTransformationProtocolType" && $protocolType eq "transformation_protocol_series") {
      my $sth2 = $dbh->prepare("select child_protocol_id from RAD.ProtocolStep where parent_protocol_id=$cfgInfo->{'protocol_id'}");
      $sth2->execute();
      while (my ($id) = $sth2->fetchrow_array()) {
	push(@protocolIds, $id);
      }
    }
    for (my $i=1; $i<scalar(@{$cfgInfo->{'protocol_param_id'}}); $i++) {
      my $isValidProtocol = 0;
      for (my $j=0; $j<@protocolIds; $j++) {
	my $protocolParam = GUS::Model::RAD::ProtocolParam->new({'protocol_param_id' =>$cfgInfo->{'protocol_param_id'}->[$i], 'protocol_id'=>$protocolIds[$j]});
	if ($protocolParam->retrieveFromDB()) {
	  $isValidProtocol = 1;
	  last;
	}
      }
      if (!$isValidProtocol) {
	$self->userError("protocol_param_id $cfgInfo->{'protocol_param_id'}->[$i], provided in the cfg_file for the $i-th protocol parameter, is not a valid protocol_param_id for protocol_id $cfgInfo->{'protocol_id'} or its components.");
      }
    }
  }
  if (defined($cfgInfo->{'protocol_qc_param_id'})) {
     my $sth1 = $dbh->prepare("select o.category, o.value from Study.OntologyEntry o, RAD.Protocol p where p.protocol_type_id=o.ontology_entry_id and p.protocol_id=$cfgInfo->{'protocol_id'}");
    $sth1->execute();
    my ($category, $protocolType) = $sth1->fetchrow_array();
    my @protocolIds = ($cfgInfo->{'protocol_id'});
    if ($category eq "DataTransformationProtocolType" && $protocolType eq "transformation_protocol_series") {
      my $sth2 = $dbh->prepare("select child_protocol_id from RAD.ProtocolStep where parent_protocol_id=$cfgInfo->{'protocol_id'}");
      $sth2->execute();
      while (my ($id) = $sth2->fetchrow_array()) {
	push(@protocolIds, $id);
      }
    }
    for (my $i=1; $i<scalar(@{$cfgInfo->{'protocol_qc_param_id'}}); $i++) {
      my $isValidProtocol = 0;
      for (my $j=0; $j<@protocolIds; $j++) {
	my $protocolQcParam = GUS::Model::RAD::ProtocolQCParam->new({'protocol_qc_param_id' =>$cfgInfo->{'protocol_qc_param_id'}->[$i], 'protocol_id'=>$protocolIds[$j]});
	if ($protocolQcParam->retrieveFromDB()) {
	  $isValidProtocol = 1;
	  last;
	}
      }
      if (!$isValidProtocol) {
	$self->userError("protocol_qc_param_id $cfgInfo->{'protocol_qc_param_id'}->[$i] for the $i-th protocol qc parameter, provided in the cfg_file, is not a valid protocol_qc_param_id for protocol_id $cfgInfo->{'protocol_id'} or its components.");
      }
    }
  }
  return $cfgInfo;
}

sub readDataFile {
  my ($self, $view, $pk, $table,$data_file) = @_;
  my $data;
  my $lineNum = 0;

  my $fh = new IO::File;
  unless ($fh->open("<$data_file")) {
    $self->error("Could not open the file $data_file.");
  }

  my %header;
  my %position;
  my $line = "";
  $self->log("Checking the data file header.");
  while ($line =~ /^\s*$/) {
    last unless $line = <$fh>;
  }

  my @arr = split(/\t/, $line);
  my $numFields = scalar(@arr);
  for (my $i=0; $i<@arr; $i++) {
    $arr[$i] =~ s/^\s+|\s+$//g;
    $arr[$i] =~ s/\"|\'//g;
    if ($header{$arr[$i]}) {
      $self->userError('No two columns can have the same name in the data file header.');
    }
    else {
      $header{$arr[$i]} = 1;
      $position{$arr[$i]} = $i;
    }
  }
  if (!$header{'row_id'}) {
    $self->userError('The data file should contain one column with header \"row_id\".');
  }
  my $v = $view->new();
  my $attribute;
  foreach my $key (keys %header) {
    if ($v->isValidAttribute($key)) {
      if ($key ne 'analysis_result_id' && $key ne 'subclass_view' && $key ne 'analysis_id' && $key ne 'table_id' && $key ne 'row_id') {
	$attribute->{$key} = $position{$key};
      }
    }
  }

  $self->logData("Valid attributes in the header:");
  my $numAttr = 0;
  foreach my $key (keys %{$attribute}) {
    $self->logData("$key");
    $numAttr++;
  }

  my $dbh = $self->getQueryHandle();
  while ($line=<$fh>) {
    $lineNum++;
    if ($lineNum % 200 == 0) {
      $self->log("Reading line $lineNum in the data file, after the header.");
    }
    if ($line =~ /^\s*$/) {
      next;
    }
    my @arr = split(/\t/, $line);
    if (scalar(@arr) != $numFields) {
      $self->userError("The number of fields on the $lineNum-th line after the header in data_file does not equal $numFields, the number of header fields.");
    }
    for (my $i=0; $i<@arr; $i++) {
      $arr[$i] =~ s/^\s+|\s+$//g;
      $arr[$i] =~ s/\"|\'//g;
      if ($arr[$i] eq "na" || $arr[$i] eq "NA" || $arr[$i] eq "n/a" || $arr[$i] eq "N/A") {
	$arr[$i] = "";
      }
    }
    if ($arr[$position{'row_id'}] ne "") {
      $data->[$lineNum]->{'row_id'} = $arr[$position{'row_id'}];
      my $rowId = $data->[$lineNum]->{'row_id'};
      my $sth = $dbh->prepare("select $pk from $table where $pk=$rowId");
      $sth->execute();
      if (!$sth->fetchrow_array()) {
	$self->userError("The row_id on line $lineNum is not a valid $pk for $table.");
      }
    }
    $data->[$lineNum]->{'discard'} = 0;
    my $numMissing = 0;
    foreach my $key (keys %{$attribute}) {
      if ($arr[$attribute->{$key}] ne "") {
	$data->[$lineNum]->{$key} = $arr[$attribute->{$key}];
      } 
      else {
	$numMissing++;
      }
    }
    if ($numMissing == $numAttr) {
      $data->[$lineNum]->{'discard'} = 1;
    }
  }
  $fh->close();
  return ($data, $lineNum);
}

sub insertAnalysis {
  my ($self, $cfgInfo) = @_;
  my ($resultDescrip, $analysisId);
  my $numAnalysisInput = 0;
  my $numAnalysisParam = 0;
  my $numAnalysisQcParam = 0;
  my $numAssayAnalysis = 0;
  my $dbh = $self->getQueryHandle();
  my @assayIds;
  my %assayCounted;

  my $analysis = GUS::Model::RAD::Analysis->new({protocol_id => $cfgInfo->{'protocol_id'}, analysis_date => $cfgInfo->{'analysis_date'}});
  if (defined $cfgInfo->{'operator_id'}) {
    $analysis->set('operator_id', $cfgInfo->{'operator_id'});
  }
  if (defined $cfgInfo->{'analysis_name'}) {
    $analysis->set('name', $cfgInfo->{'analysis_name'});
  }
  my $sth =$dbh->prepare("select t.table_id from Core.TableInfo t, Core.DatabaseInfo d where t.name='Assay' and d.name='RAD' and t.database_id=d.database_id");
  $sth->execute();
  my ($assayTableId) = $sth->fetchrow_array();

  $sth =$dbh->prepare("select t.table_id from Core.TableInfo t, Core.DatabaseInfo d where t.name='Acquisition' and d.name='RAD' and t.database_id=d.database_id");
  $sth->execute();
  my ($acquisitionTableId) = $sth->fetchrow_array();

  $sth =$dbh->prepare("select t.table_id from Core.TableInfo t, Core.DatabaseInfo d where t.name='Quantification' and d.name='RAD' and t.database_id=d.database_id");
  $sth->execute();
  my ($quantificationTableId) = $sth->fetchrow_array();

  for (my $i=0; $i<@{$cfgInfo->{'logical_group_id'}}; $i++) {
    if (defined $cfgInfo->{'logical_group_id'}->[$i]) {
      my $sth1 = $dbh->prepare("select distinct row_id from RAD.LogicalGroupLink where table_id=$assayTableId and logical_group_id= $cfgInfo->{'logical_group_id'}->[$i]");
      $sth1->execute();
      while (my ($assayId)= $sth1->fetchrow_array()) {
	if (!$assayCounted{$assayId}) {
	  push (@assayIds, $assayId);
	  $assayCounted{$assayId} = 1;
	}
      }
      my $sth2 = $dbh->prepare("select distinct a.assay_id from RAD.Acquisition a, RAD.LogicalGroupLink l where l.table_id=$acquisitionTableId and l.logical_group_id= $cfgInfo->{'logical_group_id'}->[$i] and l.row_id=a.acquisition_id");
      $sth2->execute();
      while (my ($assayId)= $sth2->fetchrow_array()) {
	if (!$assayCounted{$assayId}) {
	  push (@assayIds, $assayId);
	  $assayCounted{$assayId} = 1;
	}
      }

      my $sth3 = $dbh->prepare("select distinct a.assay_id from RAD.Acquisition a, RAD.Quantification q, RAD.LogicalGroupLink l where l.table_id=$quantificationTableId and l.logical_group_id= $cfgInfo->{'logical_group_id'}->[$i] and l.row_id=q.quantification_id and q.acquisition_id=a.acquisition_id");
      $sth3->execute();
      while (my ($assayId)= $sth3->fetchrow_array()) {
	if (!$assayCounted{$assayId}) {
	  push (@assayIds, $assayId);
	  $assayCounted{$assayId} = 1;
	}
      }

      my $analysisInput = GUS::Model::RAD::AnalysisInput->new({logical_group_id => $cfgInfo->{'logical_group_id'}->[$i]});
      if ($self->getArg('orderInput')) {
	$analysisInput->set('order_num', $i);
      }
      $analysisInput->setParent($analysis);
      $numAnalysisInput++;
    }
  }
  for (my $i=0; $i<@assayIds; $i++) {
    my $assayAnalysis = GUS::Model::RAD::AssayAnalysis->new({assay_id => $assayIds[$i]});
      $assayAnalysis->setParent($analysis);
      $numAssayAnalysis++;
  }
  if (defined($cfgInfo->{'protocol_param_id'})) {
    for (my $i=1; $i<@{$cfgInfo->{'protocol_param_id'}}; $i++) {
      my $analysisParam = GUS::Model::RAD::AnalysisParam->new({protocol_param_id => $cfgInfo->{'protocol_param_id'}->[$i], value => $cfgInfo->{'protocol_param_value'}->[$i]});
      $analysisParam->setParent($analysis);
      $numAnalysisParam++;
    }
  }
  if (defined($cfgInfo->{'protocol_qc_param_id'})) {
    for (my $i=1; $i<@{$cfgInfo->{'protocol_qc_param_id'}}; $i++) {
      my $analysisQcParam = GUS::Model::RAD::AnalysisQCParam->new({protocol_qc_param_id => $cfgInfo->{'protocol_qc_param_id'}->[$i], value => $cfgInfo->{'protocol_qc_param_value'}->[$i]});
      $analysisQcParam->setParent($analysis);
      $numAnalysisQcParam++;
    }
  }

  $analysis->submit();
  #$resultDescrip .= "Entered 1 row in RAD.Analysis, $numAnalysisInput rows in RAD.AnalysisInput, $numAssayAnalysis rows in RAD.AssayAnalysis, $numAnalysisParam rows in RAD.AnalysisParam, $numAnalysisQcParam rows in RAD.AnalysisQCParam.";
  $analysisId = $analysis->getId();
  return ($resultDescrip, $analysisId);
}

sub insertAnalysisResults {
  my ($self, $view, $analysisId, $tableId, $data, $lineCount) = @_;
  my $resultDescrip;
  my $numResults = 0;

  my ($space, $subclassView) = split(/::/, $self->getArg('subclass_view'));
  my $startLine = defined $self->getArg('restart') ? $self->getArg('restart') : 1;

  my $endLine = defined $self->getArg('testnum') ? $startLine-1+$self->getArg('testnum') : $lineCount;

  for (my $i=$startLine; $i<=$endLine; $i++) {
    if ($i % 200 == 0) {
      $self->log("Inserting data from the $i-th line.");
    }
    if (defined $data->[$i] && $data->[$i]->{'discard'} == 0) {
      $numResults++;
      my $analysisResult = $view->new({subclass_view => $subclassView, analysis_id => $analysisId});
      if (defined($data->[$i]->{'row_id'})) {
	$analysisResult->set('table_id', $tableId);
      }
      foreach my $key (keys %{$data->[$i]}) {
	if ($key ne "discard") {
	  $analysisResult->set($key, $data->[$i]->{$key});
	}
      }
      $analysisResult->submit();
    }
    $self->undefPointerCache();
  }

  #$resultDescrip = "Entered $numResults rows in RAD.$subclassView.";
  return $resultDescrip;
}

sub undoTables {
  my ($self) = @_;

  return ('RAD.AnalysisResultImp', 'RAD.AnalysisQCParam', 'RAD.AnalysisParam', 'RAD.AnalysisInput', 'RAD.AssayAnalysis', 'RAD.Analysis');
}

1;
