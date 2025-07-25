package ApiCommonData::Load::Plugin::InsertOrthoGroupBlastValues;
@ISA = qw( GUS::PluginMgr::Plugin);

use strict;
use GUS::PluginMgr::Plugin;

use ApiCommonData::Load::Psql;
use ApiCommonData::Load::Fifo;
use GUS::Model::ApiDB::OrthoGroupBlastValue;
use GUS::Model::ApiDB::OrthoGroupBlastValue_Table;

use POSIX qw(strftime);

use GUS::Supported::Util;

use File::Temp;
use File::Basename;

use Bio::Coordinate::Pair;
use Bio::Location::Simple;

use POSIX;
use Data::Dumper;

my $argsDeclaration =

  [
   fileArg({ name           => 'groupBlastValuesFile',
             descr          => 'InterGroup blast value file',
             reqd           => 1,
             mustExist      => 0,
             format         => 'tsv',
             constraintFunc => undef,
             isList         => 0,
           }),
   fileArg({ name           => 'outputBlastValuesDatFile',
             descr          => '',
             reqd           => 0,
             mustExist      => 0,
             format         => 'custom',
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
sub setBlastValueFields {$_[0]->{_blastValue_fields} = $_[1]}
sub getBlastValueFields {$_[0]->{_blastValue_fields}}

sub setOutputFileHandles {$_[0]->{_output_file_handles} = $_[1]}
sub getOutputFileHandles {$_[0]->{_output_file_handles}}
#--------------------------------------------------------------------------------

sub run {
  my ($self) = @_;

  my $dbiDb = $self->getDb();
  $dbiDb->setMaximumNumberOfObjects(100000);

  $self->setPsqlLogin();
  $self->setPsqlPassword();
  $self->setPsqlHostname();
  $self->setPsqlDatabase();
  $self->setModificationDate();

  my $groupBlastValuesFile = $self->getArg('groupBlastValuesFile');

  my $Fifo;
  
  my $outputBlastValuesDatFile = $self->getArg('outputBlastValuesDatFile');

  $Fifo = ApiCommonData::Load::Fifo->new($outputBlastValuesDatFile);
  my $blastValuesTable = GUS::Model::ApiDB::OrthoGroupBlastValue_Table->new();
  my $blastValuesPsqlObj = $self->makePsqlObj('ApiDB.OrthoGroupBlastValue', $outputBlastValuesDatFile, $blastValuesTable->getAttributeList());
  my $blastValuesPsqlProcessString = $blastValuesPsqlObj->getCommandLine();
  my $blastValuesPsqlPid = $Fifo->attachReader($blastValuesPsqlProcessString);

  $self->addActiveForkedProcess($blastValuesPsqlPid);

  my %fileHandles;
  $fileHandles{'blastValues.dat'} = $Fifo->attachWriter();
  $self->setOutputFileHandles(\%fileHandles);

  my $row_group_id = $dbiDb->getDefaultGroupId();
  my $row_user_id = $dbiDb->getDefaultUserId();
  my $row_project_id = $dbiDb->getDefaultProjectId();
  my $row_alg_invocation_id = $dbiDb->getDefaultAlgoInvoId();
  my $user_read = $dbiDb->getDefaultUserRead();
  my $user_write =  $dbiDb->getDefaultUserWrite();
  my $group_read = $dbiDb->getDefaultGroupRead();
  my $group_write = $dbiDb->getDefaultGroupWrite();
  my $other_read = $dbiDb->getDefaultOtherRead();
  my $other_write = $dbiDb->getDefaultOtherWrite();
  my $modification_date = $self->getModificationDate();

  my $dbh = $self->getQueryHandle();
  my $sql = "SELECT MAX(ortholog_blast_value_id) from apidb.orthogroupblastvalue";
  my $sh = $dbh->prepare($sql);
  $sh->execute();
  # Set to 0 if there are no rows in this table
  my $primaryKeyInt;
  while(my ($primaryKey) = $sh->fetchrow_array()) {
      $primaryKeyInt = $primaryKey;
  }
  $sh->finish();

  # If we have rows in the datbase, increate the last primary key by 1
  if ($primaryKeyInt > 0) {
    $primaryKeyInt += 1;
  }

  $primaryKeyInt = 0 unless defined $primaryKeyInt;

  open(VAL, $groupBlastValuesFile) or die "Cannot open map file $groupBlastValuesFile for reading:$!";
  while(<VAL>) {
    chomp;
    my ($group_id,$qseq,$sseq,$evalue) = split(/\t/, $_);
    $self->makeBlastValues($primaryKeyInt,$group_id,$qseq,$sseq,$evalue,$row_group_id,$row_user_id,$row_project_id,$row_alg_invocation_id,$user_read,$user_write,$group_read,$group_write,$other_read,$other_write,$modification_date);
    $primaryKeyInt += 1;  
    $self->undefPointerCache();
  }
  close VAL;

  print "$primaryKeyInt\n";

  $Fifo->cleanup();
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

sub addActiveForkedProcess {
  my ($self, $pid) = @_;

  push @{$self->{_active_forked_processes}}, $pid;
}

sub getModificationDate() { $_[0]->{_modification_date} }
sub setModificationDate {
  my ($self) = @_;
  my $modificationDate = strftime "%m-%d-%Y", localtime();
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

sub makeBlastValues {
  my ($self,$primaryKeyInt,$group_id,$qseq,$sseq,$evalue,$row_group_id,$row_user_id,$row_project_id,$row_alg_invocation_id,$user_read,$user_write,$group_read,$group_write,$other_read,$other_write,$modification_date) = @_;

  my $orthoGroupBlastValue = GUS::Model::ApiDB::OrthoGroupBlastValue->new({ ortholog_blast_value_id => $primaryKeyInt,
                                                                            group_id => $group_id,
                                                                            qseq => $qseq,
                                                                            sseq => $sseq,
                                                                            evalue => $evalue,
                                                                            row_group_id => $row_group_id,
                                                                            row_user_id => $row_user_id,
                                                                            row_project_id => $row_project_id,
                                                                            row_alg_invocation_id => $row_alg_invocation_id,
                                                                            user_read => $user_read,
                                                                            user_write =>  $user_write,
                                                                            group_read => $group_read,
                                                                            group_write => $group_write,
                                                                            other_read => $other_read,
                                                                            other_write => $other_write,
                                                                            modification_date => $modification_date
                                                                           });
  my @values = map { $orthoGroupBlastValue->get($_)} @{$self->getBlastValueFields()};
  my $fh = $self->getOutputFileHandles()->{'blastValues.dat'};
  print $fh join("\t", @values) . "\n";

  return $orthoGroupBlastValue;
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

  $self->setBlastValueFields(\@dataFields);
  $psqlObj->setFields(\@dataFields);
  
  return $psqlObj;

}

sub undoTables {
    return ("ApiDB.OrthoGroupBlastValue");
}

1;
