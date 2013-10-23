package ApiCommonData::Load::Plugin::InsertDataSource;
@ISA = qw( GUS::PluginMgr::Plugin); 

use strict;

use GUS::PluginMgr::Plugin;
use lib "$ENV{GUS_HOME}/lib/perl";
use GUS::Model::ApiDB::Datasource;
use Data::Dumper;


my $purposeBrief = <<PURPOSEBRIEF;
Insert Data Sources from a resource.xml file
PURPOSEBRIEF

my $purpose = <<PLUGIN_PURPOSE;
Insert Data Sources from a resource.xml file
PLUGIN_PURPOSE

my $tablesAffected =
	[['ApiDB.Datasource', ''],
];

my $tablesDependedOn = [];


my $howToRestart = <<PLUGIN_RESTART;
There is no restart method.
PLUGIN_RESTART

my $failureCases = <<PLUGIN_FAILURE_CASES;
There are no known failure cases.
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
   stringArg({name => 'dataSourceName',
	      descr => 'name of the data source.',
	      reqd => 1,
	      constraintFunc => undef,
	      isList => 0,
	     }),
   stringArg({name => 'version',
	      descr => 'the version of the data source.',
	      reqd => 1,
	      constraintFunc => undef,
	      isList => 0,
	     }),

   stringArg({name => 'externalDatabaseName',
	      descr => 'name of the external database associated with this data source.',
	      reqd => 1,
	      constraintFunc => undef,
	      isList => 0,
	     }),

   stringArg({name => 'taxonId',
	      descr => 'the taxonId for the organism (not the species) of the data source.  Omit if global scope',
	      reqd => 0,
	      constraintFunc => undef,
	      isList => 0,
	     }),

   stringArg({name => 'type',
	      descr => 'the type of this data source.',
	      reqd => 0,
	      constraintFunc => undef,
	      isList => 0,
	     }),

   stringArg({name => 'subType',
	      descr => 'the sub-type of this data source.  might be used to differentiate different datasets from one type in the application code',
	      reqd => 0,
	      constraintFunc => undef,
	      isList => 0,
	     }),

   booleanArg({name => 'isSpeciesScope',
	      descr => 'true if the dataset applies to the species.  (In which case the taxonId is for the reference strain)',
	      reqd => 1,
	      constraintFunc => undef,
	      isList => 0,
	     }),

  ];


sub new {
    my ($class) = @_;
    my $self = {};
    bless($self,$class); 


    $self->initialize({requiredDbVersion => 3.6,
		       cvsRevision => '$Revision$', # cvs fills this in!
		       name => ref($self),
		       argsDeclaration => $argsDeclaration,
		       documentation => $documentation
		      });

    return $self;
}

sub run {
    my ($self) = @_; 

    my $dataSourceName = $self->getArg('dataSourceName');
    my $externalDatabaseName = $self->getArg('externalDatabaseName');
    my $version = $self->getArg('version');
    my $taxonId = $self->getArg('taxonId');
    my $isSpeciesScope = $self->getArg('isSpeciesScope');
    my $type = $self->getArg('type');
    my $subType = $self->getArg('subType');

    my $objArgs = {
	name   => $dataSourceName,
	version  => $version,
	external_database_name   => $externalDatabaseName,
        taxon_id => $taxonId,
        type => $type,
        subType => $subType,
    };
    $objArgs->{is_Species_Scope} = $isSpeciesScope if $taxonId;

    my $datasource = GUS::Model::ApiDB::Datasource->new($objArgs);
    $datasource->submit();
    return "Inserted data source $dataSourceName";
}

sub undoTables {
  my ($self) = @_;

  return ('ApiDB.DataSource');
}



1;
