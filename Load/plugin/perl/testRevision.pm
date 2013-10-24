package ApiCommonData::Load::Plugin::testRevision;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;



use GUS::PluginMgr::Plugin;

my $purposeBrief = <<PURPOSEBRIEF;
PURPOSEBRIEF

my $purpose = <<PLUGIN_PURPOSE;
PLUGIN_PURPOSE

my $tablesAffected = [];

my $tablesDependedOn = [];

my $howToRestart = <<PLUGIN_RESTART;
PLUGIN_RESTART

my $failureCases = <<PLUGIN_FAILURE_CASES;
None.
PLUGIN_FAILURE_CASES

my $notes = <<PLUGIN_NOTES;
PLUGIN_NOTES

my $documentation = { purpose=>$purpose,
		      purposeBrief=>$purposeBrief,
		      tablesAffected=>$tablesAffected,
		      tablesDependedOn=>$tablesDependedOn,
		      howToRestart=>$howToRestart,
		      failureCases=>$failureCases,
		      notes=>$notes
		    };
my $argsDeclaration =
  [
   stringArg({name => 'dbRefExternalDatabaseSpec',
	      descr => 'External database release to tag the new dbRefs with (in "name|version" format)',
	      constraintFunc => undef,
	      reqd => 0,
	      isList => 0
	     })
  ];

sub new {
  my ($class) = @_;
  $class = ref $class || $class;

  my $self = bless({}, $class);

  $self->initialize({ requiredDbVersion => 3.6,
                      cvsRevision       => '$Revision$',
                      name              => ref($self),
                      argsDeclaration   => $argsDeclaration,
                      documentation     => $documentation
                   });

  return $self;
}

sub run {
return "Successfully test cvs revision!\n";
}

sub undoTables {
  my ($self) = @_;

  return (
	 );
}


1;
