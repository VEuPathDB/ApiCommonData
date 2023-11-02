package ApiCommonData::Load::Plugin::InsertExternalDatabaseRlsUD;
@ISA = qw( GUS::PluginMgr::Plugin);


use strict 'vars';

use GUS::PluginMgr::Plugin;
use lib "$ENV{GUS_HOME}/lib/perl";
use FileHandle;
use Carp;
use GUS::Model::ApidbUserDatasets::ExternalDatabaseRelease;

my $argsDeclaration = 
	[
	 stringArg({name => 'databaseName',
		    descr => 'Name in GUS of database for which we are creating a new release',
		    reqd => 1,
		    constraintFunc => undef,
		    isList => 0,
		}),

	 stringArg ({name=> 'releaseDate',
                     descr => 'release date; format appropriate for the DBMS, oracle = yyyy-mm-dd',
		     reqd => 0,
		     constraintFunc => undef,
		     isList =>0,
		 }),
	 
	 stringArg ({name => 'databaseVersion',
		    descr => 'New version of external database for which we are creating a new release',
		    reqd => 1,
		    constraintFunc => undef,
		    isList => 0,
		}),
	 
	 stringArg({name => 'downloadUrl',
		    descr => 'full url of external site from where new release can be downloaded',
		    reqd => 0,
		    constraintFunc => undef,
		    isList => 0,
		}),

	 stringArg({name => 'idType',
		    descr => 'brief description of the format of the primary identifier of entries in the release',
		    reqd => 0,
		    constraintFunc => undef,
		    isList => 0,
		}),
	 stringArg({name => 'idUrl',
		    descr => 'url to look up entries for a particular id.  If possible, replace a specific id with <ID> to provide a generalized url',
		    reqd => 0,
		    constraintFunc => undef,
		    isList => 0,
		}),

	 booleanArg({name => 'idIsAlias',
		    descr => 'the primary indentifier of entries in this release can be used as an alias for the source ID that it is linked to',
		    reqd => 0,
		    constraintFunc => undef,
                    default=> 0,
		    isList => 0,
		}),

	 stringArg({name => 'secondaryIdType',
		    descr => 'brief description of the format of the secondary identifier of entries in the release',
		    reqd => 0,
		    constraintFunc => undef,
		    isList => 0,
		}),
	 stringArg({name => 'secondaryIdUrl',
		    descr => 'url to look up entries for a particular id, by their secondary identifier.  If possible, replace a specific id with <ID> to provide a generalized url',
		    reqd => 0,
		    constraintFunc => undef,
		    isList => 0,
		}),
	 stringArg({name => 'description',
		    descr => 'description of the new release.  If possible, make the description specific to the release rather than a general description of the database itself',
		    reqd => 0,
		    constraintFunc => undef,
		    isList => 0,
		}),
	 
	 #not using fileArg for this since file is not actually opened in this plugin
	 stringArg({name => 'fileName',
		    descr => 'name of file representing this release, and if it exists, link to local location where file can be found',
		    reqd => 0,
		    constraintFunc => undef,
		    isList => 0,
		}),

	 stringArg({name => 'fileMd5',
		    descr => 'md5 checksum for verifying the file was downloaded successfully, and if it exists, link to local location where file can be found',
		    reqd => 0,
		    constraintFunc => undef,
		    isList => 0,
		})
	 ];

my $purposeBrief = <<PURPOSEBRIEF;
Creates new entry in table ApidbUserDatasets.ExternalDatabaseRelease for new external database versions
PURPOSEBRIEF
    
my $purpose = <<PLUGIN_PURPOSE;
Simple plugin that is the easiest way to create a row representing a new release of a database from an external source.  Protects against making an entry for a version that already exists for a particular database.
PLUGIN_PURPOSE

my $tablesAffected = 
	[['ApidbUserDatasets.ExternalDatabaseRelease', 'The entry representing the new release is created here']];

my $tablesDependedOn = 
	[['ApidbUserDatasets.ExternalDatabase', 'There must be an entry in this table representing the database itself; the release to be created will point to it'],
	 ['ApidbUserDatasets.ExternalDatabaseRelease', 'If there is already an entry in this table with the same version as the release to be created, then no action is taken']];
	 
my $howToRestart = <<PLUGIN_RESTART;
Only one row is created, so if the plugin fails, restart by running it again with the same parameters (accounting for any errors that may have caused the failure.
PLUGIN_RESTART
    
my $failureCases = <<PLUGIN_FAILURE_CASES;
If there is already an entry in ApidbUserDatasets.ExternalDatabaseRelease that has the same version number as the entry to be created, then no new row is submitted.  This is not a failure case per se, but will result in no change to the database where one might have been expected.  Also, if including --releaseDate in the command line, the format of the date must be the same as that expected by the DATE datatype in your database instance, oracle yyyy-mm-dd.
PLUGIN_FAILURE_CASES

my $notes = <<PLUGIN_NOTES;
Although currently ApidbUserDatasets.ExternalDatabaseRelease contains attributes named blast_file and blast_file_md5, they are unpopulated in CBILs instance and it is unclear what they are used for, so the ability to load data into them is not provided here.
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

  $self->initialize({requiredDbVersion => 4.0,
		     cvsRevision => '$Revision$', # cvs fills this in!
		     name => ref($self),
		     argsDeclaration   => $argsDeclaration,
		     documentation     => $documentation
		    });

  return $self;
}

#######################################################################
# Main Routine
#######################################################################

sub run {
    my ($self) = @_;

    my $dbName = $self->getArg('databaseName');
    my $dbVer = $self->getArg('databaseVersion'); 
    my $msg;

    my $dbId = $self->getExtDbId($dbName);

    if ($self->releaseAlreadyExists($dbId)){
	$msg = "Not creating a new release Id for $dbName as there is already one for $dbName version $dbVer";
    }

    else{
	my $extDbRelId = $self->makeNewReleaseId($dbId);
	$msg = "Created new release id for $dbName with version $dbVer and release id $extDbRelId";
    }

    return $msg;
}

#######################################################################
# Subroutines
#######################################################################

# ---------------------------------------------------------------------
# releaseAlreadyExists
# ---------------------------------------------------------------------

sub releaseAlreadyExists{
    my ($self, $id) = @_;

    my $dbVer = $self->getArg('databaseVersion'); 

    my $sql = "select external_database_release_id 
               from ApidbUserDatasets.ExternalDatabaseRelease
               where external_database_id = $id
               and version = '$dbVer'";

    my $sth = $self->prepareAndExecute($sql);
    my ($relId) = $sth->fetchrow_array();

    return $relId; #if exists, entry has already been made for this version

}

# ---------------------------------------------------------------------
# makeNewReleaseId
# ---------------------------------------------------------------------

sub makeNewReleaseId{
    my ($self, $id) = @_;
    my $dbVer = $self->getArg('databaseVersion'); 

    my $newRelease = GUS::Model::ApidbUserDatasets::ExternalDatabaseRelease->new({
	external_database_id => $id,
	version => $dbVer,
	download_url => $self->getArg('downloadUrl'),
	id_type => $self->getArg('idType'),
	id_url => $self->getArg('idUrl'),
        release_date => $self->getArg('releaseDate'),
	id_is_alias => $self->getArg('idIsAlias'),
	secondary_id_type => $self->getArg('secondaryIdType'),
	secondary_id_url => $self->getArg('secondaryIdUrl'),
	description => $self->getArg('description'),
	file_name => $self->getArg('fileName'),
	file_md5 => $self->getArg('fileMd5'),
	
    });

    $newRelease->submit();
    my $newReleasePk = $newRelease->getId();

    return $newReleasePk;

}

# ---------------------------------------------------------------------
# getExtDbId
# ---------------------------------------------------------------------

sub getExtDbId{
    my ($self, $name, ) = @_;
	my $lcName = lc($name);
    my $sql = "select external_database_id from ApidbUserDatasets.ExternalDatabase where lower(name) = '$lcName'";

    my $sth = $self->prepareAndExecute($sql);
   
    my ($id) = $sth->fetchrow_array();

    if (!($id)){
	$self->userError("no entry in ApidbUserDatasets.ExternalDatabase for database $name");
    }
    else{
	return $id;
    }
}

sub undoTables {
  my ($self) = @_;

  return ('ApidbUserDatasets.ExternalDatabaseRelease');
}

1;
