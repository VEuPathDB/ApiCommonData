package ApiCommonData::Load::Plugin::InsertPlasmoMappWithSqlLdr;
@ISA = qw(GUS::PluginMgr::Plugin);


use strict;

use GUS::Supported::GusConfig;
use GUS::PluginMgr::Plugin;

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
  my $purpose = "Inserts ApiDB.PlasmoMapp.";

  my $purposeBrief = "";

  my $tablesAffected = [['ApiDB.PlasmoMapp', 'One Row to Identify Malaria Promoter Predictor']];

  my $tablesDependedOn = [];

  my $howToRestart = "No restart";

  my $failureCases = "";

  my $notes = "";

  my $documentation = {purpose=>$purpose, purposeBrief=>$purposeBrief, tablesAffected=>$tablesAffected, tablesDependedOn=>$tablesDependedOn, howToRestart=>$howToRestart, failureCases=>$failureCases,notes=>$notes};

  return $documentation;
}

#--------------------------------------------------------------------------------

sub new {
  my ($class) = @_;
  my $self = {};
  bless($self,$class);

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

  $self->writeConfigFile($configFile,$dataFile);

  my $login       = $self->getConfig->getDatabaseLogin();

  my $password    = $self->getConfig->getDatabasePassword();

  my $dbiDsn      = $self->getConfig->getDbiDsn();

  my ($dbi, $type, $db) = split(':', $dbiDsn);

  system("sqlldr $login/$password\@$db control=$configFile log=$logFile") if($self->getArg('commit'));
    
  return "Processed lines from data files";
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
INTO TABLE ApiDB.PlasmoMapp
FIELDS TERMINATED BY '\\t'
TRAILING NULLCOLS
(na_sequence_id,
strand,
location,
value,
row_alg_invocation_id constant $algInvocationId
)\n";
  close CONFIG;
}

sub getConfig {
  my ($self) = @_;

  if (!$self->{config}) {
    my $gusConfigFile = $self->getArg('gusconfigfile');
     $self->{config} = GUS::Supported::GusConfig->new($gusConfigFile);
   }

  $self->{config};
}

sub undoTables {
  my ($self) = @_;

  return ('ApiDB.PlasmoMapp');
}

1;

