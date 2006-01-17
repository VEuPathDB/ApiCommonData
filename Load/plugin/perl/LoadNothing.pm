#############################################################################
##                    LoadNothing.pm
##
## Plugin to do nothing: intended for use in the resources pipeline so it
## doesn't complain when we want to aquire something without immediately
## using it
##
## $Id$
##
## created January 9, 2006  by Jennifer Dommer
#############################################################################

package ApiCommonData::Load::Plugin::LoadNothing;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;

use GUS::PluginMgr::Plugin;

my $purposeBrief = <<PURPOSEBRIEF;
Place holder to do nothing
PURPOSEBRIEF

my $purpose = <<PLUGIN_PURPOSE;
Place holder to do nothing. Optionally takes an external database name and version.
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
    my $self = {};
    bless($self,$class);

    $self->initialize({requiredDbVersion => 3.5,
		       cvsRevision => '$Revision$', # cvs fills this in!
		       name => ref($self),
		       argsDeclaration => $argsDeclaration,
		       documentation => $documentation
		      });

    return $self;
}


sub run {
return "Successfully did nothing\n";
}

1;
