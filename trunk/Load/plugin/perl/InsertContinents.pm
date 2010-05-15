package ApiCommonData::Load::Plugin::InsertContinents;

@ISA = qw(GUS::PluginMgr::Plugin);

# ----------------------------------------------------------------------

use strict;
use GUS::PluginMgr::Plugin;

use GUS::Model::ApiDB::Continents;



my $argsDeclaration =
  [

   fileArg({name           => 'continentsFile',
            descr          => 'file with continents info',
            reqd           => 1,
            mustExist      => 1,
	    format         => '',
            constraintFunc => undef,
            isList         => 0, }),

  ];

my $purpose = <<PURPOSE;

PURPOSE

my $purposeBrief = <<PURPOSE_BRIEF;

PURPOSE_BRIEF

my $notes = <<NOTES;

NOTES

my $tablesAffected = <<TABLES_AFFECTED;
ApiDB::Continents
TABLES_AFFECTED

my $tablesDependedOn = <<TABLES_DEPENDED_ON;
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

  open(FILE, $self->getArg('continentsFile')) || die "Could Not open continents file for reading: $!\n";
  my ($continent,$count);

  while(<FILE>) {
      chomp;
      next unless $_;

      if(/(.+)\(\d+\)/) {
	  $continent = lc($1);
	  $continent =~ s/\s$//g;
      }
      else {
	  my $country = $_;
	  $country =~ s/\s$//g;
	  my $profile = GUS::Model::ApiDB::Continents->
	      new({country => $country,
		   continent => $continent
		   });
	  $profile->submit();

	  $count++;
	  if ($count % 1000 == 0) {
	      $self->log("Inserted $count Entries into Continents");
	      $self->undefPointerCache();

	  }
      }

  }
  return("Loaded $count ApiDB::Continents");
}

sub undoTables {
  my ($self) = @_;

  return ('ApiDB.Continents',
	 );
}

1;
