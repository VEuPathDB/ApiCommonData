package ApiCommonData::Load::Plugin::InsertProfileElementFromLongString;

@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use GUS::PluginMgr::Plugin;
use FileHandle;

use GUS::Model::PlasmoDB::Profile;
use GUS::Model::PlasmoDB::ProfileElement;

my $argsDeclaration =
[

 stringArg({ descr => 'Name of the External Database for ProfileSet',
	     name  => 'extDbName',
	     isList    => 0,
	     reqd  => 1,
	     constraintFunc => undef,
	   }),

 stringArg({ descr => 'Version of the External Database Release for ProfileSet',
	     name  => 'extDbVersion',
	     isList    => 0,
	     reqd  => 1,
	     constraintFunc => undef,
	   }),

];

my $purpose = <<PURPOSE;
Convert a long string of profiles from plasmoDB.profile.Profile_as_string into several plasmoDb.profileElement s
PURPOSE

my $purposeBrief = <<PURPOSE_BRIEF;
Convert a long string of profiles from plasmoDB.profile.Profile_as_string into several plasmoDb.profileElement s
PURPOSE_BRIEF

my $notes = <<NOTES;
NOTES

my $tablesAffected = <<TABLES_AFFECTED;
Plasmodb::ProfileElement
TABLES_AFFECTED

my $tablesDependedOn = <<TABLES_DEPENDED_ON;
Plasmodb::Profile
Plasmodb::ProfileSet
TABLES_DEPENDED_ON

my $howToRestart = <<RESTART;
There are no restart facilities for this plugin
RESTART

my $failureCases = <<FAIL_CASES;
FAIL_CASES

my $documentation = { purpose          => $purpose,
		      purposeBrief     => $purposeBrief,
		      notes            => $notes,
		      tablesAffected   => $tablesAffected,
		      tablesDependedOn => $tablesDependedOn,
		      howToRestart     => $howToRestart,
		      failureCases     => $failureCases };

# ----------------------------------------------------------------------

sub new {
  my ($class) = @_;
  my $self = {};
  bless($self,$class);

  $self->initialize({ requiredDbVersion => 3.5,
		      cvsRevision       => '$Revision$',
		      name              => ref($self),
		      argsDeclaration   => $argsDeclaration,
		      documentation     => $documentation});

  return $self;
}

# ======================================================================

sub run {
  my ($self) = @_;

  my $extDbRlsId = $self->getExtDbRlsId($self->getArgs()->{extDbName}, 
					 $self->getArgs()->{extDbVersion});

  my $sql = "select profile_id, profile_as_string 
             from plasmodb.profile where profile_set_id in (
                 select profile_set_id 
                 from plasmodb.profileSet 
                 where external_database_release_id = $extDbRlsId)";

  my $sh = $self->getQueryHandle()->prepare($sql);
  $sh->execute();

  my $profileCount;
  my $totalElementCount;
  while(my ($id, $string) = $sh->fetchrow_array()) {
    my @elements = split(/\t/, $string);

    my $profile = GUS::Model::PlasmoDB::Profile->
      new({ profile_id => $id });

    if($profile->retrieveFromDB()) {

      my $orderNum = 1;
      foreach (@elements) {
        my $profileElement = GUS::Model::PlasmoDB::ProfileElement->
          new({ value => $_,
                element_order => $orderNum,
              });

        $profileElement->setParent($profile);

        $orderNum++;
        $totalElementCount++;
      }
    }
    else {
      die "Cannot retrieve profile $id from db: $!";
    }

    if($profileCount++ % 500 == 0) {
      $self->log("Processed $profileCount Profiles.");
    }

    $profile->submit();
    $self->undefPointerCache();
  }
  $sh->finish();

  return("Processed $profileCount Profiles and Inserted $totalElementCount ProfileElements");
}

1;
