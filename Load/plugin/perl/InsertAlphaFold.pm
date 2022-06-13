package ApiCommonData::Load::Plugin::InsertAlphaFold;
use lib "$ENV{GUS_HOME}/lib/perl";
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use GUS::PluginMgr::Plugin;
use GUS::Supported::Util;
use GUS::Model::ApiDB::AlphaFold;
use Data::Dumper;
use File::Temp qw/ tempfile /;
use POSIX qw/strftime/;

sub getArgsDeclaration {
    my $argsDeclaration  =
	[
	 
	 stringArg({ name => 'inputFile',
		     descr => 'accession_ids.txt file from AlphaFold',
		     constraintFunc=> undef,
		     reqd  => 1,
		     isList => 0,
		     mustExist => 1,
		   }),

   stringArg({name => 'extDbSpec',                                                                                                                                                                         
              descr => 'External database from whence this data came|version',
              constraintFunc=> undef,
              reqd  => 1,
              isList => 0
             }),
	];
    
    return $argsDeclaration;
}


sub getDocumentation {
    
    my $description = <<NOTES;
Load mappings between Uniprot ids and AlphaFold ids.
NOTES
	
	my $purpose = <<PURPOSE;
Load mappings between Uniprot ids and AlphaFold ids.
PURPOSE
	
	my $purposeBrief = <<PURPOSEBRIEF;
Load mappings between Uniprot ids and AlphaFold ids.
PURPOSEBRIEF
	
	my $syntax = <<SYNTAX;
SYNTAX
	
	my $notes = <<NOTES;
NOTES
	
	my $tablesAffected = <<AFFECT;
ApiDB.AlphaFold
AFFECT
	
	my $tablesDependedOn = <<TABD;
TABD
	
	my $howToRestart = <<RESTART;
There are no restart facilities for this plugin
RESTART
	
	my $failureCases = <<FAIL;
FAIL
	
	my $documentation = {purpose=>$purpose, purposeBrief=>$purposeBrief,tablesAffected=>$tablesAffected,tablesDependedOn=>$tablesDependedOn,howToRestart=>$howToRestart,failureCases=>$failureCases,notes=>$notes};
    
    return ($documentation);
}



sub new {
    my $class = shift;
    my $self = {};
    bless($self, $class);
    
    my $documentation = &getDocumentation();
    
    my $args = &getArgsDeclaration();
    
    $self->initialize({requiredDbVersion => 4.0,
		       cvsRevision => '$Revision$',
		       name => ref($self),
		       argsDeclaration   => $args,
		       documentation     => $documentation
		      });
    return $self;
}

sub run {
    my $self = shift;
   
    my $extDbSpec = $self->getArg('extDbSpec');
    my $extDbRlsId = $self->getExtDbRlsId($extDbSpec) or die "Couldn't find source db: $extDbSpec\n"; 

    my ($ctrlFh, $ctrlFile) = tempfile(SUFFIX => '.dat');

    my $inputFile = $self->getArg('inputFile');

    $self->loadAlphaFold($inputFile, $ctrlFile, $extDbRlsId);

}

sub loadAlphaFold {
    my ($self, $inputFile, $ctrlFile, $extDbRlsId) = @_;

    my $ctrlFile = "$ctrlFile.ctrl";
    my $logFile = "$ctrlFile.log";

    $self->writeConfigFile($ctrlFile, $inputFile, $extDbRlsId);

    my $login = $self->getConfig->getDatabaseLogin();
    my $password = $self->getConfig->getDatabasePassword();
    my $dbiDsn = $self->getConfig->getDbiDsn();
    my ($dbi, $type, $db) = split(':', $dbiDsn);

    if($self->getArg('commit')) {
        my $exitstatus = system("sqlldr $login/$password\@$db control=$ctrlFile log=$logFile rows=1000");
        if ($exitstatus != 0){
            die "ERROR: sqlldr returned exit status $exitstatus";
        }

        open(LOG, $logFile) or die "Cannot open log file $logFile: $!";
        while (<LOG>) {
            $self->log($_);
        }
        close LOG;
        unlink $logFile;
    }
    unlink $ctrlFile;
}

sub writeConfigFile {                                                                                                                                                                                      
  my ($self, $configFile, $inputFile, $extDbRlsId) = @_;

  my $modDate = uc(strftime("%d-%b-%Y", localtime));
  my $database = $self->getDb();
  my $projectId = $database->getDefaultProjectId();
  my $userId = $database->getDefaultUserId();
  my $groupId = $database->getDefaultGroupId();
  my $algInvocationId = $database->getDefaultAlgoInvoId();
  my $userRead = $database->getDefaultUserRead();
  my $userWrite = $database->getDefaultUserWrite();
  my $groupRead = $database->getDefaultGroupRead();
  my $groupWrite = $database->getDefaultGroupWrite();
  my $otherRead = $database->getDefaultOtherRead();
  my $otherWrite = $database->getDefaultOtherWrite();

  open(CONFIG, "> $configFile") or die "Cannot open file $configFile For writing:$!";

  print CONFIG "LOAD DATA
CHARACTERSET UTF8
INFILE '$inputFile'
APPEND
INTO TABLE ApiDB.AlphaFold
REENABLE DISABLED_CONSTRAINTS
FIELDS TERMINATED BY ','
TRAILING NULLCOLS
(
alphafold_id SEQUENCE(MAX,1),
uniprot_id,
first_residue_index,
last_residue_index,
source_id,
alphafold_version,
external_database_release_id constant $extDbRlsId,
modification_date constant \"$modDate\",
user_read constant $userRead,
user_write constant $userWrite,
group_read constant $groupRead,
group_write constant $groupWrite,
other_read constant $otherRead,
other_write constant $otherWrite,
row_user_id constant $userId,
row_group_id constant $groupId,
row_project_id constant $projectId,
row_alg_invocation_id constant $algInvocationId
)\n";
  close CONFIG;
}

sub getConfig {
    my ($self) = @_;

    if(!$self->{config}) {
        my $gusConfigFile = $self->getArg('gusconfigfile');
        $self->{config} = GUS::Supported::GusConfig->new($gusConfigFile);
    }
    $self->{config}
}



sub undoTables {
  my ($self) = @_;

  return ('ApiDB.AlphaFold');
}

1;
