package ApiCommonData::Load::Plugin::MakeAveragedProfiles;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;

use GUS::PluginMgr::Plugin;
use Tie::IxHash;
use GUS::Model::ApiDB::ProfileSet;
use GUS::Model::ApiDB::Profile;
use ApiCommonData::Load::ExpressionProfileInsertion;

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
	      format => 'newline delimited set of comma separated lists, with a name separated by a colon. Each list is a set of columns in the current profile to average. Ex:
              time1:1,4,7
              time2:2,6',
	     }),
     booleanArg ({name => 'loadProfileElement',
		  descr => 'Set this to load the ProfileElement table with the individual profile elements',
		  reqd => 0,
		  default =>0
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
  my $profileSet = $self->getProfileSet($profileName);

  my $configFile = $self->getArg('configFile');
  my $sets = $self->parseConfig($configFile);

  my $newProfileSetId = $self->makeNewProfileSet($profileName, $profileSet, $sets);

  my ($count, $skipped) = $self->averageProfiles($profileSet, $newProfileSetId, $sets, $profileSet->getSourceIdType());

  my $msg = "Submitted $count new averaged profiles. Skipped $skipped because they were already found in the database.";

  return $msg;
}


sub getProfileSet{
  my ($self, $profileName) = @_;

  my $profileSet  = GUS::Model::ApiDB::ProfileSet->new({'name'=>$profileName});

  unless($profileSet->retrieveFromDB()){
    $self->error("ProfileSet Name not (uniquely) matched". $profileSet->getName());
  }

  return $profileSet;
}

sub makeNewProfileSet{
  my ($self, $profileName, $profileSet, $sets) = @_;
  my $newProfileName = $profileName."-Averaged";

  my @header = (keys %{$sets});

  my $newProfileSet = &makeProfileSet($self, $profileSet->getExternalDatabaseReleaseId(), \@header, $newProfileName, $profileSet->getDescription(), $profileSet->getSourceIdType());

  if($newProfileSet->retrieveFromDB()){
    $self->error("There is already a profile set with the name '$newProfileName'. I cannot create this set.");
  }

  $newProfileSet->submit();
  return $newProfileSet->getId();
}

sub parseConfig{
  my ($self, $configFile) = @_;
  tie my %sets, "Tie::IxHash";

  $self->log("Retrieving list of sets...\n");
  open(FILE, $configFile) or die "Could not open the file '$configFile': $!\n";

  while(<FILE>){
    chomp;

    my ($name, $cols) = split(':',$_);
    my @vals = split(',',$cols);
    push(@{$sets{$name}}, @vals);
  }

  close(FILE);

  return \%sets;
}

sub averageProfiles{
  my ($self, $profileSet, $newProfileSetId, $sets, $sourceIdType) = @_;
  my $count = 0;
  my $skipped = 0;
  my $profileSetId = $profileSet->getId();

  $self->log("Creating averaged proviles...");

  my $sql = "select profile_id from ApiDB.Profile where profile_set_id = $profileSetId";

  my $dbh = $self->getQueryHandle();
  my $stmt = $dbh->prepareAndExecute($sql);

  while(my $profileId = $stmt->fetchrow_array()){
    my @avgs;

    my $profileObj = GUS::Model::ApiDB::Profile->new({'profile_id' => $profileId});
    $profileObj->retrieveFromDB();

    my $profile = $profileObj->getProfileAsString();

    my @values = split("\t", $profile);

    foreach my $name (keys %{$sets}){
      foreach my $set ($$sets{$name}){
	my $avg = $self->calculateAverage($set, \@values);
	push(@avgs, $avg);
      }
    }

    unshift(@avgs, $profileObj->getSourceId());

    ($count, $skipped) = $self->createNewProfile(\@avgs, $newProfileSetId, $sourceIdType, $count, $skipped);

    if ($count % 100 == 0){
      $self->log("Created $count new averaged profiles.");
      $self->undefPointerCache();
    }
  }

  return ($count, $skipped);
}

sub calculateAverage{
  my($self, $set, $values) = @_;
  my $sum = 0;

  foreach my $element (@{$set}){
    $sum += $$values[$element-1];
  }

  my $n = @{$set};
  my $avg = $sum/$n;

  return $avg;
}

sub createNewProfile{
  my($self, $avgProfile, $newProfileSetId, $sourceIdType, $count, $skipped) = @_;
  my $elementCount = scalar(@{$avgProfile}) - 1;

  my $newProfile = &makeProfile($self, $avgProfile, $newProfileSetId, $elementCount, $sourceIdType, 1, $self->getArg('loadProfileElement'));

  if($newProfile->retrieveFromDB()){
    $self->log("There is already an averaged profile for ". $newProfile->getId().". Skipping profile.");
    $skipped++;
  }

  $newProfile->submit();
  $count++;

  return ($count, $skipped);
}

sub undoTables {
  my ($self) = @_;

  return ('ApiDB.Profile',
	  'ApiDB.ProfileElementName',
	  'ApiDB.ProfileSet',
	 );
}

1;
