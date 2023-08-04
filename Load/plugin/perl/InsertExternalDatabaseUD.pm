#######################################################################
##                 InsertExternalDatabase.pm
##
## Creates a new entry in table SRes.ExternalDatabase to represent
## a new source of data imported into GUS
## $Id$
##
#######################################################################
 
package GUS::Supported::Plugin::InsertExternalDatabaseUD;
@ISA = qw( GUS::PluginMgr::Plugin);

use strict 'vars';


use GUS::PluginMgr::Plugin;
use lib "$ENV{GUS_HOME}/lib/perl";
use FileHandle;
use Carp;
use GUS::Model::ApidbUserDatasets::ExternalDatabase;

my $argsDeclaration = 
  [
   stringArg({name => 'name',
	      descr => 'name of the external database to be inserted',
	      reqd => 1,
	      constraintFunc => undef,
	      isList => 0,
	     })
  ];


my $purposeBrief = <<PURPOSEBRIEF;
Creates a new entry in table ApidbUserDatasets.ExternalDatabase to represent a new source of data imported into GUS.
PURPOSEBRIEF
    
my $purpose = <<PLUGIN_PURPOSE;
Simple plugin that is the easiest way to create a row representing a new database that exists in the outside world that will be imported into GUS.  This entry serves as a stable identifier across multiple releases of the database (which are stored in ApidbUserDatasets.ExternalDatabaseRelease and point back to the entry created by this plugin).  Protects against making multiple entries in GUS for an external database that already exists there (see notes below).
PLUGIN_PURPOSE
    
my $tablesAffected = 
	[['ApidbUserDatasets.ExternalDatabase', 'The entry representing the new external database is created here']];

my $tablesDependedOn = [];

my $howToRestart = <<PLUGIN_RESTART;
Only one row is created, so if the plugin fails, restart by running it again with the same parameters (accounting for any errors that may have caused the failure.
PLUGIN_RESTART

my $failureCases = <<PLUGIN_FAILURE_CASES;
If the entry already exists, based on the --name flag and a corresponding name in the table, then the plugin does not submit a new row.  This is not a failure case per se, but will result in no change to the database where one might have been expected.
PLUGIN_FAILURE_CASES

my $notes = <<PLUGIN_NOTES;
The way the plugin checks to make sure there is not already an entry representing this database is by case-insensitive matching against the name.  There is a chance, however, that the user could load a duplicate entry, representing the same database, but with different names, because of a misspelling or alternate naming convention.  This cannot be guarded against, so it is up to the user to avoid duplicate entries when possible.
PLUGIN_NOTES

my $documentation = { purpose=>$purpose,
		      purposeBrief=>$purposeBrief,
		      tablesAffected=>$tablesAffected,
		      tablesDependedOn=>$tablesDependedOn,
		      howToRestart=>$howToRestart,
		      failureCases=>$failureCases,
		      notes=>$notes
		    };

sub new {
    my ($class) = @_;
    my $self = {};
    bless($self,$class);
 

    $self->initialize({requiredDbVersion => 4,
		       cvsRevision => '$Revision$', # cvs fills this in!
		       name => ref($self),
		       argsDeclaration => $argsDeclaration,
		       documentation => $documentation
		      });

    return $self;
}

#######################################################################
# Main Routine
#######################################################################

sub run {
    my ($self) = @_;
    my $dbName = $self->getArg('name');
    my $msg;

    my $sql = "select external_database_id from ApidbUserDatasets.externaldatabase where lower(name) like '" . lc($dbName) ."'";
    my $sth = $self->prepareAndExecute($sql);
    my ($dbId) = $sth->fetchrow_array();

    if ($dbId){
	$msg = "Not creating a new entry for $dbName as one already exists in the database (id $dbId)";
    }

    else {
	my $newDatabase = GUS::Model::ApidbUserDatasets::ExternalDatabase->new({
	    name => $dbName,
	   });
	$newDatabase->submit();
	my $newDatabasePk = $newDatabase->getId();
	$msg = "created new entry for database $dbName with primary key $newDatabasePk";
    }

    return $msg;
}

sub undoTables {
  my ($self) = @_;

  return ('ApidbUserDatasets.ExternalDatabase');
}

1;
