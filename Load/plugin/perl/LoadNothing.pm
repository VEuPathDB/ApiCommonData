#############################################################################
#vvvvvvvvvvvvvvvvvvvvvvvvv GUS4_STATUS vvvvvvvvvvvvvvvvvvvvvvvvv
  # GUS4_STATUS | SRes.OntologyTerm              | auto   | absent
  # GUS4_STATUS | SRes.SequenceOntology          | auto   | absent
  # GUS4_STATUS | Study.OntologyEntry            | auto   | absent
  # GUS4_STATUS | SRes.GOTerm                    | auto   | absent
  # GUS4_STATUS | Dots.RNAFeatureExon            | auto   | absent
  # GUS4_STATUS | RAD.SageTag                    | auto   | absent
  # GUS4_STATUS | RAD.Analysis                   | auto   | absent
  # GUS4_STATUS | ApiDB.Profile                  | auto   | absent
  # GUS4_STATUS | Study.Study                    | auto   | absent
  # GUS4_STATUS | Dots.Isolate                   | auto   | absent
  # GUS4_STATUS | DeprecatedTables               | auto   | absent
  # GUS4_STATUS | Pathway                        | auto   | absent
  # GUS4_STATUS | DoTS.SequenceVariation         | auto   | absent
  # GUS4_STATUS | RNASeq Junctions               | auto   | absent
  # GUS4_STATUS | Simple Rename                  | auto   | absent
  # GUS4_STATUS | ApiDB Tuning Gene              | auto   | absent
  # GUS4_STATUS | Rethink                        | auto   | absent
  # GUS4_STATUS | dots.gene                      | manual | absent
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^
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
  $class = ref $class || $class;

  my $self = bless({}, $class);

  $self->initialize({ requiredDbVersion => 4.0,
                      cvsRevision       => '$Revision$',
                      name              => ref($self),
                      argsDeclaration   => $argsDeclaration,
                      documentation     => $documentation
                   });

  return $self;
}

sub run {
return "Successfully did nothing\n";
}

sub undoTables {
  my ($self) = @_;

  return (
	 );
}


1;
