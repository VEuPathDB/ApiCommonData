package ApiCommonData::Load::Plugin::InsertNextGenSeqCoverageWithSqlLdr;
@ISA = qw(GUS::PluginMgr::Plugin);


use strict;

use GUS::Supported::GusConfig;
use GUS::PluginMgr::Plugin;

use GUS::Model::Study::OntologyEntry;

$| = 1;

# ---------------------------------------------------------------------------
# Load Arguments
# ---------------------------------------------------------------------------

sub getArgumentsDeclaration{
  my $argsDeclaration =
    [

     fileArg({ name           => 'dataFile',
               descr          => 'Sql loader input file',
               reqd           => 1,
               mustExist      => 1,
               format         => '',
               constraintFunc => undef,
               isList         => 0,
             }),
    ];
  return $argsDeclaration;
}

# ----------------------------------------------------------------------
# Documentation
# ----------------------------------------------------------------------

sub getDocumentation {
  my $purpose = "Inserts apidb.nextgenseq_coverage.";

  my $purposeBrief = "Inserts Rad.Analysis and Rad.AnalysisResultImp View.  Creates the associated Rad.Protocol if it doesn't exist";

  my $tablesAffected = [['apidb.nextgenseq_coverage', 'One Row to Identify sequence coverage']];

  my $tablesDependedOn = [['Study::OntologyEntry',  'new protocols will be assigned unknown_protocol_type'],
                          ['DoTS::GeneFeature', 'The id in the data file must ge an existing Gene Feature']];

  my $howToRestart = "No restart";

  my $failureCases = "";

  my $notes = "The first column in the data file specifies the Dots.GeneFeature SourceId.  Subsequent columns are view specific. (ex:  fold_change for DifferentialExpression OR float_value for DataTransformationResult).  The Config file has the following columns (no header):file analysis_name protocol_name protocol_type(OPTOINAL)";

  my $documentation = {purpose=>$purpose, purposeBrief=>$purposeBrief, tablesAffected=>$tablesAffected, tablesDependedOn=>$tablesDependedOn, howToRestart=>$howToRestart, failureCases=>$failureCases,notes=>$notes};

  return $documentation;
}

#--------------------------------------------------------------------------------

sub new {
  my ($self) = @_;
  my $documentation = &getDocumentation();
  my $argumentDeclaration = &getArgumentsDeclaration();

  $self->initialize({requiredDbVersion => 3.5,
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

  my $dataFile = $self->getArg('dataFile');

  my $configFile = "$dataFile" . ".ctrl";
 
  my $logFile = "$dataFile" . ".log";

  $self->writeConfigFile($configFile);
  
}

#--------------------------------------------------------------------------------
sub writeConfigFile {
  my ($self, $configFile, $dataFile) = @_;

  my $database = $self->getDb();
  my $algInvocationId = $database->getDefaultAlgoInvoId();

  open(CONFIG, "> $configFile") or die "Cannot open file $configFile For writing:$!";


  print CONFIG "LOAD DATA
INFILE '$dataFile'
APPEND
INTO TABLE apidb.nextgenseq_coverage
FIELDS TERMINATED BY '\\t'
TRAILING NULLCOLS
(external_database_release_id,
sample,
na_sequence_id,
location,
coverage,
multiple,
row_alg_invocation_id constant '$algInvocationId',
)\n";
  close CONFIG;
}

sub undoTables {
  my ($self) = @_;

  return ('apidb.nextgenseq_coverage');
}

1;

