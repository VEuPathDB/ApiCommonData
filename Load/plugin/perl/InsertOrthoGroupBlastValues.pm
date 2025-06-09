package ApiCommonData::Load::Plugin::InsertOrthoGroupBlastValues;
@ISA = qw( GUS::PluginMgr::Plugin);

use strict;
use GUS::PluginMgr::Plugin;

use ApiCommonData::Load::Psql;
use GUS::Model::ApiDB::OrthoGroupBlastValue;

use POSIX qw(strftime);

my $argsDeclaration = 

  [
   fileArg({ name           => 'groupBlastValuesFile',
	     descr          => 'InterGroup blast value file',
	     reqd           => 1,
	     mustExist      => 0,
	     format         => 'tsv',
	     constraintFunc => undef,
	     isList         => 0,
	   })
  ];

my $purposeBrief = <<PURPOSEBRIEF;
Create entries for OrthoGroupBlastValue
PURPOSEBRIEF
    
my $purpose = <<PLUGIN_PURPOSE;
Create entries for OrthoGroupBlastValue
PLUGIN_PURPOSE

my $tablesAffected = "ApiDB.OrthoGroupBlastValue";

my $tablesDependedOn = [];

my $howToRestart = <<PLUGIN_RESTART;
Simply reexecute the plugin.
PLUGIN_RESTART

my $failureCases = <<PLUGIN_FAILURE_CASES;
None.
PLUGIN_FAILURE_CASES

my $notes = <<PLUGIN_NOTES;
None.
PLUGIN_NOTES

my $documentation = { purpose=>$purpose,
		      purposeBrief=>$purposeBrief,
		      tablesAffected=>$tablesAffected,
		      tablesDependedOn=>$tablesDependedOn,
		      howToRestart=>$howToRestart,
		      failureCases=>$failureCases,
		      notes=>$notes
		    };

#--------------------------------------------------------------------------------

sub new {
    my ($class) = @_;
    my $self = {};
    bless($self,$class);

    $self->initialize({requiredDbVersion => 4.0,
		       cvsRevision => '$Revision$', # cvs fills this in!
		       name => ref($self),
		       argsDeclaration => $argsDeclaration,
		       documentation => $documentation
		      });

    return $self;
}

#--------------------------------------------------------------------------------

sub error {
  my ($self, $msg) = @_;
  print STDERR "\nERROR: $msg\n";

  foreach my $pid (@{$self->getActiveForkedProcesses()}) {
    kill(9, $pid);
  }

  $self->SUPER::error($msg);
}

sub getActiveForkedProcesses {
  my ($self) = @_;

  return $self->{_active_forked_processes} || [];
}

#--------------------------------------------------------------------------------

sub run {
  my ($self) = @_;

  my $dbiDb = $self->getDb();
  $dbiDb->setMaximumNumberOfObjects(100000);

  my $dirname = $self->getArg('groupBlastValuesFile');

  $self->setPsqlLogin();
  $self->setPsqlPassword();
  $self->setPsqlHostname();
  $self->setPsqlDatabase();
  $self->setModificationDate();

  my $groupBlastValuesFile = $self->getArg('groupBlastValuesFile');
     
  my @attributes = ['qseq','sseq','evalue','group_id'];

  #  my $groupBlastValueTable = GUS::Model::ApiDB::OrthoGroupBlastValue_Table->new();
  my $groupBlastValueTable = GUS::Model::ApiDB::OrthoGroupBlastValue->new();
  my $groupBlastValuePsqlObj = $self->makePsqlObj('ApiDB.OrthoGroupBlastValue', $groupBlastValuesFile, @attributes);
  my $groupBlastValueProcessString = $groupBlastValuePsqlObj->getCommandLine();
  system("$groupBlastValueProcessString");
}

sub setOrthoGroupBlastValueFields {$_[0]->{_orthogroupblastvalue_fields} = $_[1]}
sub getOrthoGroupBlastValueFields {$_[0]->{_orthogroupblastvalue_fields} }

sub getModificationDate() { $_[0]->{_modification_date} }
sub setModificationDate {
  my ($self) = @_;
  my  $modificationDate;
  $modificationDate = strftime "%m-%d-%Y", localtime();
  $self->{_modification_date} = $modificationDate;
}

sub getPsqlLogin() { $_[0]->{_psql_login} }
sub setPsqlLogin() {
  my ($self) = @_;
  $self->{_psql_login} = $self->getDb->getLogin();
}

sub getPsqlPassword() { $_[0]->{_psql_password} }
sub setPsqlPassword() {
  my ($self) = @_;
  $self->{_psql_password} = $self->getDb->getPassword();
}

sub getPsqlDatabase() { $_[0]->{_psql_database} }
sub setPsqlDatabase {
  my ($self) = @_;

  my $dbiDsn      = $self->getDb->getDSN();
  $dbiDsn =~ /(:|;)dbname=((\w|\.)+);?/ ;
  my $db = $2;
  $self->{_psql_database} = $db;
}

sub getPsqlHostname() { $_[0]->{_psql_hostname} }
sub setPsqlHostname {
  my ($self) = @_;

  my $dbiDsn      = $self->getDb->getDSN();
  $dbiDsn =~ /(:|;)host=((\w|\.)+);?/ ;
  my $hostName = $2;
  $self->{_psql_hostname} = $hostName;
}

sub makePsqlObj {
  my ($self, $tableName, $datFileName, $attributeList) = @_;

  my $psqlObj = ApiCommonData::Load::Psql->new({
    _login => $self->getPsqlLogin(),
    _password => $self->getPsqlPassword(),
    _database => $self->getPsqlDatabase(),
    _hostName=> $self->getPsqlHostname(),
    _quiet => 0,
  });

  $psqlObj->setInfileName($datFileName);
  $psqlObj->setTableName($tableName);
  $psqlObj->setFieldDelimiter("\t");

  my @dataFields = map { lc($_) } grep { lc($_) ne 'tstarts' && lc($_) ne 'blocksizes'} @$attributeList;  

  $self->setOrthoGroupBlastValueFields(\@dataFields);

  $psqlObj->setFields(\@dataFields);
  
  return $psqlObj;
}

sub undoTables {
  return ("ApiDB.OrthoGroupBlastValue");
}

1;
