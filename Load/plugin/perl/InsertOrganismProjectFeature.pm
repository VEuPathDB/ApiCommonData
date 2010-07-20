package ApiCommonData::Load::Plugin::InsertOrganismProjectFeature;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use warnings;

use GUS::PluginMgr::Plugin;
use GUS::Model::ApiDB::OrganismProject;


# ----------------------------------------------------------
# Load Arguments
# ----------------------------------------------------------

  my $argsDeclaration  =
    [
     stringArg({ name => 'organism',
		 descr => 'organism name',
		 constraintFunc=> undef,
		 reqd  => 1,
		 isList => 0,
	       }),
     stringArg({ name => 'projectName',
		 descr => 'project name',
		 constraintFunc=> undef,
		 reqd  => 1,
		 isList => 0,
	       }),
    ];


# ----------------------------------------------------------
# Documentation
# ----------------------------------------------------------

  my $description = <<DESCR;
Plugin to load organism and project mappings
DESCR

  my $purpose = <<PURPOSE;
PURPOSE

  my $purposeBrief = <<PURPOSEBRIEF;
Add project organism name mappings
PURPOSEBRIEF

  my $notes = <<NOTES;
NOTES

  my $tablesAffected = <<AFFECT;
ApiDB.OrganismProject
AFFECT

  my $tablesDependedOn = <<TABD;
TABD

  my $howToRestart = <<RESTART;
No restart provided. Undo and re-run.
RESTART

  my $failureCases = <<FAIL;
FAIL

  my $documentation = { purpose          => $purpose,
			purposeBrief     => $purposeBrief,
			tablesAffected   => $tablesAffected,
			tablesDependedOn => $tablesDependedOn,
			howToRestart     => $howToRestart,
			failureCases     => $failureCases,
			notes            => $notes
		      };


sub new {
  my ($class) = @_;
  my $self = {};
  bless($self, $class);

  $self->initialize ({ requiredDbVersion => 3.5,
			cvsRevision => '$Revision$',
			name => ref($self),
			argsDeclaration => $argsDeclaration,
			documentation => $documentation
		      });

  return $self;
}

sub run {
  my ($self) = @_;

  my $organism = $self->getArg('organism');

  my $project = $self->getArg('projectName');

  my $organismProject =  GUS::Model::ApiDB::OrganismProject->new({'organism' => $organism,
					     'project' => $project,});

  $organismProject->submit() unless $organismProject->retrieveFromDB();

  my $msg = "$project -> $organism added to apidb.OrganismProject.";

  $self->log("$msg \n");

  return $msg;
}



sub undoTables {
  return qw(ApiDB.OrganismProject
           );
}
