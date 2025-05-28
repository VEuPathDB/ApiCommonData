package ApiCommonData::Load::Plugin::CreateDenormalizedTable;
@ISA = qw(GUS::PluginMgr::Plugin ApiCommonData::Load::Plugin::ParameterizedSchema);

use strict;
use File::Basename;
use GUS::PluginMgr::Plugin;
use ApiCommonData::Load::InstantiatePsql;
use ApiCommonData::Load::Plugin::ParameterizedSchema;

my $purposeBrief = <<PURPOSEBRIEF;
Create denormalized tables.
PURPOSEBRIEF

my $purpose = <<PLUGIN_PURPOSE;
Create denormalized tables.
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

The undo logic is custom.  It acquires the plugin arg values, and from those infers SCHEMA, ORG_ABBREV and MY_DENORM_TABLE.  
It drops the denormalized table.
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
  $class = ref $class || $class;

  my $self = bless({}, $class);

  $self->initialize({ requiredDbVersion => 4.0,
                      cvsRevision       => '$Revision$',
                      name              => ref($self),
                      argsDeclaration   => $argsDeclaration,
                      documentation     => $documentation
                   });

  $self->{_undo_tables} = [];
  return $self;
}

sub run {
  my ($self) = @_;

  my $psqlDirPath = $self->getArg('psqlDirPath');
  my $tableName = $self->getArg($TABLE_NAME_ARG);
  my $schema = $self->getArg($SCHEMA_ARG);
  my $projectId = $self->getArg('projectId');
  my $organismAbbrev = $self->getArg($ORG_ARG);
  my $mode = $self->getArg('mode');
  my $taxonId = $self->getArg('taxonId');

  my $dbh = $self->getQueryHandle();
  $dbh->{RaiseError} = 1;
  $dbh->{AutoCommit} = 1;
  my $commitMode = $self->getArg('commit');

  $dbh->do("set role gus_w");

  my $fileName = "$psqlDirPath/$tableName.psql";
  -e $fileName or $self->error("psqlFile $fileName does not exist");

  if ($mode eq 'child') {
    $self->error("organismAbbrev and taxonId are required if mode is 'child'") unless $organismAbbrev && $taxonId;
  } else {
    $self->error("organismAbbrev must be null if mode is 'standard' or 'parent") if $organismAbbrev;
  }

  my $startTimeAll = time;
  $self->processPsqlFile($fileName, $tableName, $schema, $organismAbbrev, $mode, $taxonId, $projectId, $commitMode, $dbh);
  if ($mode ne 'child' && -e "$psqlDirPath/${tableName}_ix.psql") {
    $self->processPsqlFile("$psqlDirPath/${tableName}_ix.psql", 'dontcare', $schema, $organismAbbrev, 'dontcare', 'dontcare', 'dontcare', $commitMode, $dbh);
  }
  my $t = time - $startTimeAll;
  $self->log("TOTAL SQL TIME (sec) for table $tableName: $t");
}

sub processPsqlFile {
  my ($self, $psqlFilePath, $tableName, $schema, $organismAbbrev, $mode, $taxonId, $projectId, $commitMode, $dbh) = @_;

  $self->log("Processing file $psqlFilePath");
  open my $fh, '<', $psqlFilePath or $self->error("error opening $psqlFilePath: $!");
  my $sqls = do { local $/; <$fh> };

  my $newSqls = ApiCommonData::Load::InstantiatePsql::instantiateSql($sqls, $tableName, $schema, $organismAbbrev, $mode, $taxonId, $projectId);

  my @sqlList = split(/;\n\s*/, $newSqls);
  foreach my $sql (@sqlList) {
    my $startTime = time;

    $self->log(( $commitMode? "FOR REAL" : "TEST ONLY" ). " - SQL: \n$sql\n\n");
    if ($commitMode) {
      $dbh->do($sql);
    }
    my $t = time - $startTime;
    $self->log("INDVIDUAL SQL TIME (sec): $t");
  }
}

sub undoPreprocess {
  my($self, $dbh, $rowAlgInvocationList) = @_;

  $self->error("Expected a single rowAlgInvocationId") if scalar(@$rowAlgInvocationList) != 1;

  my $tableNames = $self->getAlgorithmParam($dbh, $rowAlgInvocationList, $TABLE_NAME_ARG);
  my $schemas = $self->getAlgorithmParam($dbh, $rowAlgInvocationList, $SCHEMA_ARG);
  my $orgAbbrevs = $self->getAlgorithmParam($dbh, $rowAlgInvocationList, $ORG_ARG);

  my $tableName = $tableNames->[0];
  my $schema = $schemas->[0];
  my $orgAbbrev = $orgAbbrevs->[0];

  my $sql = "drop table if exists $schema.${tableName}_temporary";
  $dbh->do($sql) || $self->error("Failed executing $sql");
  $self->log("Dropped $schema.$tableName");
  my $sql = "drop table if exists " . $orgAbbrev? "$schema.$tableName.\"_\".$orgAbbrev" : "$schema.$tableName";
  $dbh->do($sql) || $self->error("Failed executing $sql");
  $self->log("Dropped $schema.$tableName");

}

sub undoTables {
  my ($self) = @_;

  return @{ $self->{_undo_tables} }
}

1;
