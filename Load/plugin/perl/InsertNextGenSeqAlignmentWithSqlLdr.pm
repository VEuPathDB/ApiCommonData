package ApiCommonData::Load::Plugin::InsertNextGenSeqAlignmentWithSqlLdr;
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

      stringArg({name => 'externalDatabase',
	      descr => 'External database from whence this data came',
	      constraintFunc=> undef,
	      reqd  => 1,
	      isList => 0
	     }),

   stringArg({name => 'externalDatabaseRls',
	      descr => 'Version of external database from whence this data came',
	      constraintFunc=> undef,
	      reqd  => 1,
	      isList => 0
	     }),
    ];
  return $argsDeclaration;
}

# ----------------------------------------------------------------------
# Documentation
# ----------------------------------------------------------------------

sub getDocumentation {
  my $purpose = "Inserts apidb.NextGenSeq_Align.";

  my $purposeBrief = "";

  my $tablesAffected = [['apidb.NextGenSeq_Align', 'One Row to Identify sequence align']];

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
INTO TABLE apidb.nextgenseq_align
FIELDS TERMINATED BY '\\t'
TRAILING NULLCOLS
(nextgenseq_align_id \"apidb.nextgenseq_align_sq.nextval\",
external_database_release_id integer external,
sample char,
na_sequence_id integer external,
query_id char,
strand char,
start_a integer external,
end_a integer external,
start_b integer external,
end_b integer external,
intron_size integer external,
genome_matches integer external,
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

  return ('apidb.nextgenseq_align');
}

1;

