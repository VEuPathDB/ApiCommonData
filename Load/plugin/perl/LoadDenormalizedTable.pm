package ApiCommonData::Load::Plugin::LoadDenormalizedTable;
use lib "$ENV{GUS_HOME}/lib/perl";
use base qw(GUS::PluginMgr::Plugin ApiCommonData::Load::Plugin::CreateDenormalizedTable);

# this subclass of CreateDenormalized table overrides the Undo method
# the Undo method runs a psql file rather than dropping tables
# the psql file for the undo should be located with the psql for loading and named Drop_TableName.psql
# initial use is for TranscriptPathway, which requires us to empty but not drop the table on undo

use strict;
use warnings;
use File::Basename;
use GUS::PluginMgr::Plugin;
use ApiCommonData::Load::InstantiatePsql;
use ApiCommonData::Load::Plugin::ParameterizedSchema;

my $purposeBrief = <<PURPOSEBRIEF;
Create denormalized tables, run psql on undo.
PURPOSEBRIEF

my $purpose = <<PLUGIN_PURPOSE;
Create denormalized tables, run psql on undo.
PLUGIN_PURPOSE

my $tablesAffected = [];

my $tablesDependedOn = [];

my $howToRestart = <<PLUGIN_RESTART;
PLUGIN_RESTART

my $failureCases = <<PLUGIN_FAILURE_CASES;
None.
PLUGIN_FAILURE_CASES

my $notes = <<PLUGIN_NOTES;
Input is directory containing a .psql file, and the name of the table this .psql file will create, eg MY_DENORM_TABLE. The file MY_DENORM_TABLE.psql
controls creation of MY_DENORM_TABLE.  The file contains multiple SQL statements (roughly corresponding to SQL blocks in tuning manager XML files).
 The sqls are delimited by a semi-colon followed by newline.  The files use .psql style macro variables.

The files are named using this pattern:
 - MY_DENORM_TABLE.psql
 - MY_DENORM_TABLE_ix.psql    -declares indexes for MY_DENORM_TABLE

The following values are passed in to the psql as macro values, for use in org-specific .psql files:
 - :SCHEMA                 - the target schema
 - :PROJECT_ID
 - :ORG_ABBREV             - only for org-specific tables
 - :TAXON_ID               - only for org-specific tables
 - :CREATE_AND_POPULATE    - only for org-specific tables
 - :DECLARE_PARTITION      - only for org-specific tables

A typical MY_DENORM_TABLE.psql file might look like this:
create :SCHEMA.:ORG_ABBREVtemp_table_1 as select...
:CREATE_AND_POPULATE 
select ....           --this is the main SELECT statement for the web table
:DECLARE_PARTITION
drop :SCHEMA.:ORG_ABBREVtemp_table_1

The parallel MY_DENORM_TABLE_ix.psql file might look like this:
create index :SCHEMA.:ORG_ABBREVmy_index on :SCHEMA.:ORG_ABBREVMY_DENORM_TABLE;

This plugin requires that org specific tables in the .psql file be of the form :SCHEMA.:ORG_ABBREVmy_table

For organism-specific cases, the plugin runs in one of two modes:
 - parent
 - child

If any table we try to create already exists, we will get a database error.

This subclass runs an SQL on undo rather than dropping a table. The SQL to be run on undo must be named Drop_MY_DENORM_TABLE.psql
PLUGIN_NOTES

my $documentation = { purpose=>$purpose,
		      purposeBrief=>$purposeBrief,
		      tablesAffected=>$tablesAffected,
		      tablesDependedOn=>$tablesDependedOn,
		      howToRestart=>$howToRestart,
		      failureCases=>$failureCases,
		      notes=>$notes
		    };

my $TABLE_NAME_ARG = 'tableName';
my $SCHEMA_ARG = 'schema';
my $ORG_ARG = 'organismAbbrev';

my $argsDeclaration =
  [
   enumArg({ name => 'mode',
	     descr => 'standard for non-org-specific.  parent for parent partition.  child for child partition',
	     constraintFunc => undef,
	     reqd => 1,
	     isList => 0,
	     enum => 'standard, parent, child'
	   }),
   fileArg({name           => 'psqlDirPath',
            descr          => '',
            reqd           => 1,
            mustExist      => 1,
            format         => '',
            constraintFunc => undef,
            isList         => 0, }),
   stringArg({name => $TABLE_NAME_ARG,
	      descr => 'name of table to create, eg MY_DENOM_TABLE',
	      constraintFunc => undef,
	      reqd => 1,
	      isList => 0
	     }),
    stringArg({name => $SCHEMA_ARG,
	      descr => 'schema to hold MY_DENOM_TABLE and temp tables',
	      constraintFunc => undef,
	      reqd => 1,
	      isList => 0
	     }),
   stringArg({name => 'projectId',
	      descr => 'eg PlasmoDB',
	      constraintFunc => undef,
	      reqd => 1,
	      isList => 0
	     }),
   stringArg({name => $ORG_ARG,
	      descr => 'internal organism abbrev, if this table has organism specific rows',
	      constraintFunc => undef,
	      reqd => 0,
	      isList => 0
	     }),
   stringArg({name => 'taxonId',
	      descr => 'taxon id, if this table has organism specific rows',
	      constraintFunc => undef,
	      reqd => 0,
	      isList => 0
	     }),
  ];

sub new {
  my ($class) = @_;
  my $self = bless ({}, $class);

  $self->initialize({   requiredDbVersion => 4.0,
                        cvsRevision => '$Revision$',
                        name => ref($self),
                        argsDeclaration => $argsDeclaration,
                        documentation => $documentation
                    });

    $self->{_undo_tables} = [];

  # I don't think we need to do anything different here
  #my $self = $class->SUPER::new();

  return $self;
}

#sub run {
#    my ($self) = @_;
#    $self->SUPER::run();
#}

sub undoPreprocess {
  my($self, $dbh, $rowAlgInvocationList) = @_;

  $self->error("Expected a single rowAlgInvocationId") if scalar(@$rowAlgInvocationList) != 1;

  $self->log("UNDOing alg invocation id: $rowAlgInvocationList->[0]");

  # we will be running psql here, so we need anything that could be substituted in the SQL
  my $tableNames = $self->getAlgorithmParam($dbh, $rowAlgInvocationList, $TABLE_NAME_ARG);
  my $schemas = $self->getAlgorithmParam($dbh, $rowAlgInvocationList, $SCHEMA_ARG);
  my $orgAbbrevs = $self->getAlgorithmParam($dbh, $rowAlgInvocationList, $ORG_ARG);
  my $projectIds = $self->getAlgorithmParam($dbh, $rowAlgInvocationList, 'projectId');
  my $taxonIds = $self->getAlgorithmParam($dbh, $rowAlgInvocationList, ,'taxonId');
  my $psqlDirPaths = $self->getAlgorithmParam($dbh, $rowAlgInvocationList, 'psqlDirPath');

  my $tableName = $tableNames->[0];
  my $schema = $schemas->[0];
  my $orgAbbrev = $orgAbbrevs->[0];
  my $projectId = $projectIds->[0];
  my $taxonId = $taxonIds->[0];
  my $psqlDirPath = $psqlDirPaths->[0];

  $dbh->do("set role gus_w");

  # get the undo sql by inference from the original file.
  my $fileName = "${psqlDirPath}/Undo_${tableName}.psql";
  -e $fileName or $self->error("psqlFile $fileName does not exist");

  my $startTimeAll = time;
  #this runs the sql
  #ATTENTION - this will always run in commit mode
  $self->processPsqlFile($fileName, $tableName, $schema, $orgAbbrev, 'standard', $taxonId, $projectId, 1, $dbh);

#TODO: I don't want to do anything with the index for TranscriptPathways, but is there a use case for this?
#  if ($mode ne 'child' && -e "$psqlDirPath/${tableName}_ix.psql") {
#    $self->processPsqlFile("$psqlDirPath/${tableName}_ix.psql", 'dontcare', $schema, $organismAbbrev, 'dontcare', 'dontcare', 'dontcare', $commitMode, $dbh);
#  }
  my $t = time - $startTimeAll;
  $self->log("TOTAL SQL TIME (sec) for table $tableName: $t");

  $self->log("Undone $tableName by running $fileName");

}

1;
