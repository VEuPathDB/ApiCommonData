package ApiCommonData::Load::Plugin::InsertSnps;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;

use GUS::PluginMgr::Plugin;
use GUS::Model::ApiDB::ProfileSet;
use GUS::Model::ApiDB::Profile;


sub getArgumentsDeclaration{
  my $argsDeclaration =
    [
     stringArg({name => 'profileSetName',
		descr => 'ApiDB.ProfileSet.name for set that is to be averaged',
		constraintFunc => undef,
		reqd => 1,
		isList => 0
	       }),
     fileArg({name => 'configFile',
	      descr => 'file specifying which columns should be averaged',
	      constraintFunc=> undef,
	      reqd  => 1,
	      isList => 0,
	      mustExist => 1,
	      format => 'newline delimited set of comma separated lists. Each list is a set of columns in the current profile to average. Ex:
              1,4,7
              2,6',
	     }),
    ];
  return $argsDeclaration;
}

# ----------------------------------------------------------------------
# Documentation
# ----------------------------------------------------------------------

sub getDocumentation {
  my $purposeBrief = "Calculates and inserts averaged profile data into ApiDB.Profile, creating a new ApiDB.ProfileSet.";

  my $purpose = "Calculates averaged profile data from entries that have been entered into ApiDB.Profile from RAD and inserts the averaged profiles into ApiDB.Profile.  The new profile is linked to a new ApiDB.ProfileSet that is created by appending ' - Averaged' to the name of the original ApiDB.ProfileSet.  All names in ApiDB.ProfileSet must be unique.";

  my $tablesAffected = [['ApiDB::ProfileSet', 'A new row is created containing the new set name.'],['ApiDB::Profile', 'Multiple rows are created containing the averaged profiles.']];

  my $tablesDependedOn = [['ApiDB::ProfileSet', 'The original set name must be found here, and must be unique.'],['ApiDB::Profile','The original profiles must be found here.']];

  my $howToRestart = "";

  my $failureCases = "If the ApiDB.ProfileSet.name is not unique the plugin will fail.";

  my $notes = "";

  my $documentation = {purpose=>$purpose,
		       purposeBrief=>$purposeBrief,
		       tablesAffected=>$tablesAffected,
		       tablesDependedOn=>$tablesDependedOn,
		       howToRestart=>$howToRestart,
		       failureCases=>$failureCases,
		       notes=>$notes};

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

  return $self;
}


sub run{
  my ($self) = @_;

  my $profileName = $self->getArg('profileSetName');
  my $profileSetId = $self->getProfileSetId($profileName);

  my $newProfileSetId = $self->makeProfileSet($profileName);

  my $configFile = $self->getArg('configFile');
  my $sets = $self->parseConfig($configFile);

  my ($count, $skipped) = $self->averageProfiles($profileSetId, $newProfileSetId, $sets);

  my $msg = "Submitted $count new averaged profiles. Skipped $skipped because they were already found in the database.";

  return $msg;
}


sub getProfileSetId{
  my ($self, $profileName) = @_;

  my $profileSet  = GUS::Model::ApiDB::ProfileSet->new({'name'=>$profileName});

  unless($profileSet->retrieveFromDB()){
    $self->error("ProfileSet Name not (uniquely) matched". $profileSet->getName());
  }

  return $profileSet->getId();
}

sub makeProfileSet{
  my ($self, $profileName) = @_;
  my $newProfileName = $profileName."-1";

  my $profile = GUS::Model::ApiDB::ProfileSet->new({'name'=>$newProfileName});

  if($profile->retrieveFromDB()){
    $self->error("There is already a profile set with the name '$newProfileName'. I cannot create this set.");
  }

  $profile->submit();
  return $profile->getId();
}

sub parseConfig{
  my ($self, $configFile) = @_;
  my @sets;

  $self->log("Retrieving list of sets...\n");
  open(FILE, $configFile) or die "Could not open the file '$configFile': $!\n";

  while(<FILE>){
    chomp;

    my @set = split(',',$_);

    push(@sets, @set);
  }

  close(FILE);

  return \@sets;
}

sub averageProfiles{
  my ($self, $profileSetId, $newProfileSetId, $sets) = @_;
  my $count = 0;
  my $skipped = 0;

  $self->log("Creating averaged proviles...");

  my $sql = "select * from ApiDB.Profile where profile_set_id = $profileSetId";

  my $dbh = $self->getQueryHandle();
  my $stmt = $dbh->prepareAndExecute($sql);

  while(my $profileObj = $stmt->fetchrow_array()){
    my @avgs;

    my $profile = $profileObj->getProfileAsString();
    my @values = split("\t", $profile);

    foreach my $set (@{$sets}){
      my $avg = $self->calculateAverage($set, \@values);
      push(@avgs, $avg);
    }

    my $avgProfile = join("\t", @avgs);
    $self->createNewProfile($avgProfile, $newProfileSetId, $profileObj, \$count, \$skipped);

    if ($count % 100 == 0){
      $self->log("Created $count new averaged profiles.");
    }
  }

  return ($count, $skipped);
}

sub calculateAverage{
  my($set, $values) = @_;
  my $sum = 0;

  foreach my $element (@{$set}){
    $element--;
    $sum += $values[$element];
  }

  my $n = @set;
  my $avg = $sum/$n;

  return $avg;
}

sub createNewProfile{
  my($avgProfile, $newProfileSetId, $profileObj, $count, $skipped) = @_;

  my $newProfile = GUS::Model::ApiDB::Profile->new({
		   'profile_set_id' => $newProfileSetId,
		   'subject_table_id' => $profileObj->getSubjectTableId(),
		   'subject_row_id' => $profileObj->getSubjectRowId(),
		   'source_id' => $profileObj->getId(),
		   'profile_as_string' => $avgProfile,
		  });

  if($newProfile->retrieveFromDB()){
    $self->log("There is already an averaged profile for ". $profileObj->getId().". Skipping profile.");
    $skipped ++;
  }

  $newProfile->submit();
  $count ++;

}

1;
