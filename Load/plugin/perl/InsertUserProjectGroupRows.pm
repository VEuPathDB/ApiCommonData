package ApiCommonData::Load::Plugin::InsertUserProjectGroupRows;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;

use GUS::PluginMgr::Plugin;
use GUS::Model::Core::UserInfo;
use GUS::Model::Core::GroupInfo;
use GUS::Model::Core::ProjectInfo;
use GUS::Model::Core::UserGroup;
use GUS::Model::Core::UserProject;
use CBIL::Util::PropertySet;

$| = 1;

my @properties = 
(
 ["coreSchemaName",   "",  ""],
 ["userName",   "",  ""],
 ["group",   "",  ""],
 ["project",   "",  ""],
 ["dbiDsn",    "",  ""],
 ["databaseLogin",         "",  ""],
 ["databasePassword",   "",  ""],
 ["readOnlyDatabaseLogin",         "",  ""],
 ["readOnlyDatabasePassword",   "",  ""]
);

# ---------------------------------------------------------------------------
# Load Arguments
# ---------------------------------------------------------------------------

sub getArgumentsDeclaration{
  my $argsDeclaration =
    [
     stringArg({name => 'nameUser',
		descr => 'comma delimited list with first,last to insert into userinfo first_name and last_name',
		constraintFunc => undef,
		reqd => 0,
		isList => 1
	       }),
     stringArg({name => 'userLogin',
		descr => 'identical to userName in a gus config file, inserted as userinfo.login, defaults to value in current users GUS_PROPERTIES file',
		constraintFunc => undef,
		reqd => 0,
		isList => 0
	       }),
     stringArg({name => 'groupName',
		descr => 'name attribute for core.groupinfo.name, defaults to value in current users GUS_PROPERTIES file',
		constraintFunc => undef,
		reqd => 0,
		isList => 0
	       }),
     stringArg({name => 'projectName',
		descr => 'name of project for core.projectinfo, defaults to value in current users GUS_PROPERTIES file',
		constraintFunc => undef,
		reqd => 0,
		isList => 0
	       }),
     stringArg({name => 'projectRelease',
		descr => 'release number for core.projectinfo.release',
		constraintFunc=> undef,
		reqd  => 0,
		isList => 0
	       })
    ];
  return $argsDeclaration;
}

# ----------------------------------------------------------------------
# Documentation
# ----------------------------------------------------------------------

sub getDocumentation {
  my $purposeBrief = "Inserts entries into core.GroupInfo,core.ProjectInfo,core.UserProject,core.UserGroup, and sres.Contact.";

  my $purpose = "Inserts entries into core.GroupInfo,core.ProjectInfo,core.UserProject,core.UserGroup, and sres.Contact as initial pipeline steps.";

  my $tablesAffected = [['Core::UserInfo', 'One row updated per user'],['Core::ProjectInfo', 'One row inserted per project'],['Core::UserProject', 'One row inserted to link the user and project'],['Core::GroupInfo', 'One row inserted per group affiliation'],['Core::Usergroup', 'One row inserted to link user and group'],];

  my $tablesDependedOn = [['Core::UserInfo', 'row in userinfo must exist with userinfo.login consistent with userName in the gus properties file']];

  my $howToRestart = "No extra steps required for restart";

  my $failureCases = "";

  my $notes = "";

  my $documentation = {purpose=>$purpose, purposeBrief=>$purposeBrief, tablesAffected=>$tablesAffected, tablesDependedOn=>$tablesDependedOn, howToRestart=>$howToRestart, failureCases=>$failureCases,notes=>$notes};

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
  my $argumentDeclaration = &getArgumentsDeclaration();


  $self->initialize({requiredDbVersion => 3.5,
		     cvsRevision => '$Revision$',
                     name => ref($self),
                     revisionNotes => '',
                     argsDeclaration => $argumentDeclaration,
                     documentation => $documentation});

  my $gusConfigFile = $ENV{GUS_CONFIG_FILE};
  $self->{propertySet} = CBIL::Util::PropertySet->new($gusConfigFile,\@properties);

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

  my $userId = $self->getUserInfoId();

  my $projectId = $self->getProjectInfoId();

  my $groupId = $self->getGroupInfoId();

  $self->insertUserProject($userId,$projectId);

  $self->insertUserGroup($userId,$groupId);

  my $login = $self->getArg('userLogin');

  my $project = $self->getArg('projectName');

  my $groupName = $self->getArg('groupName');

  my $release = $self->getArg('projectRelease');

  my $resultDescrip = "Rows inserted or already exist in core.userinfo,projectinfo,groupinfo,userproject,usergroup for userName = $login,project = $project, project release $release,and group = $groupName.";

  $self->setResultDescr($resultDescrip);
  $self->logData($resultDescrip);
}


sub getUserInfoId {
  my ($self) = @_;

  my $login = $self->getArg('userLogin') ? $self->getArg('userLogin') : $self->{propertySet}->getProp('userName');

  my $userInfo = GUS::Model::Core::UserInfo->new({'login'=>$login});

  $userInfo->retrieveFromDB();

  $userInfo->setFirstName($self->getArg('nameUser')->[0]) if ($self->getArg('nameUser') && $self->getArg('nameUser')->[0] ne $userInfo->getFirstName());

  $userInfo->setLastName($self->getArg('nameUser')->[1]) if ($self->getArg('nameUser') && $self->getArg('nameUser')->[1] ne $userInfo->getLastName());

  $userInfo->setPassword($login) if ($userInfo->getPassword() ne $login);

  $userInfo->setEMail('unknown') if ($userInfo->getEMail() ne 'unknown');

  $userInfo->submit();

  my $userId = $userInfo->getId();

  return $userId;
}

sub getProjectInfoId {
  my ($self) = @_;

  my $projectHash;

  if(defined $self->getArg('projectRelease'))  {  $projectHash->{release}=$self->getArg('projectRelease');}

  $projectHash->{name} = $self->getArg('projectName') ? $self->getArg('projectName') : $self->{propertySet}->getProp('project');

  my $projectInfo = GUS::Model::Core::ProjectInfo->new($projectHash);

  if (! $projectInfo->retrieveFromDB()) {

    $projectInfo->submit();
  }

  my $projectId = $projectInfo->getId();

  return $projectId;

}

sub getGroupInfoId {
  my ($self) = @_;

  my $groupName = $self->getArg('groupName') ? $self->getArg('groupName') : $self->{propertySet}->getProp('group');

  my $groupInfo = GUS::Model::Core::GroupInfo->new({'name'=>$groupName});

  if (! $groupInfo->retrieveFromDB()) {
    $groupInfo->submit();
  }

  my $groupId = $groupInfo->getId();

  return $groupId;

}

sub insertUserProject {
   my ($self,$userId,$projectId) = @_;

   my $userProject =  GUS::Model::Core::UserProject->new({'user_id'=>$userId,'project_id'=>$projectId});

   if (! $userProject->retrieveFromDB()) {
     $userProject->submit();
   }
}

sub insertUserGroup {
   my ($self,$userId,$groupId) = @_;

   my $userGroup =  GUS::Model::Core::UserGroup->new({'user_id'=>$userId,'group_id'=>$groupId});

   if (! $userGroup->retrieveFromDB()) {
     $userGroup->submit();
   }
}

1;
