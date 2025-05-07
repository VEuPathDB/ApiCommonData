package ApiCommonData::Load::Plugin::CreateDenormalizedTables;
@ISA = qw(GUS::PluginMgr::Plugin ApiCommonData::Load::Plugin::ParameterizedSchema);

use strict;
use File::Basename;
use GUS::PluginMgr::Plugin;

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
Input is a MY_DENORM_TABLE.psql file that controls creation of or insertion into MY_DENORM_TABLE.  The file contains multiple SQL statements
(roughly corresponding to SQL blocks in tuning manager XML files).   The sqls are delimited by a semi-colon followed by newline.  The files use
.psql style macro variables.

The files are named using this pattern: MY_DENORM_TALE.psql

The following values are passed in to the psql as macro values, for use in org-specific .psql files:
 - :SCHEMA                 - the target schema
 - :ORG_ABBREV             - only for org-specific tables
 - :TAXON_ID               - only for org-specific tables
 - :CREATE_AND_POPULATE    - only for org-specific tables
 - :DECLARE_PARTITION      - only for org-specific tables

A typical org-specific file might look like this:
create :SCHEMA.:ORG_ABBREVtemp_table_1 as select...
:CREATE_AND_POPULATE 
select ....           --this is the main SELECT statement for the web table
:DECLARE_PARTITION
create :SCHEMA.:ORG_ABBREVmy_table_ix_1
drop :SCHEMA.:ORG_ABBREVtemp_table_1

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

my $PSQL_FILE_ARG = 'psqlFile';
my $SCHEMA_ARG = 'schema';
my $ORG_ARG = 'schema';

my $argsDeclaration =
  [
   enumArg({ name => 'mode',
	     descr => 'standard for non-org-specific.  parent for parent partition.  child for child partition',
	     constraintFunc => undef,
	     reqd => 1,
	     isList => 0,
	     enum => 'standard, parent, child'
	   }),
   fileArg({name           => $PSQL_FILE_ARG,
            descr          => '',
            reqd           => 1,
            mustExist      => 1,
            format         => '',
            constraintFunc => undef,
            isList         => 0, }),
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
   stringArg({name => $TAXON_ID_ARG,
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

  my $psqlFilePath = $self->getArg($PSQL_FILE_ARG);
  my $schema = $self->getArg($SCHEMA_ARG);
  my $projectId = $self->getArg('projectId');
  my $organismAbbrev = $self->getArg($ORG_ARG);
  my $mode = $self->getArg('mode');
  my $taxonId = $self->getArg('taxonId');

  my $dbh = $self->getQueryHandle();
  $dbh->{RaiseError} = 1;
  $dbh->{AutoCommit} = 1;
  my $commitMode = $self->getArg('commit');

  my $fileName = basename($psqlFilePath);
  $fileName =~ /(.+).psql/ or $self->error("psqlFile name must be in form MY_DENORM_TABLE.psql");
  my $tableName = $1;

  if ($mode eq 'child') {
    $self->error("organismAbbrev and taxonId are required if mode is 'child'") unless $organismAbbrev && $taxonId;
  } else {
    $self->error("organismAbbrev and taxon_id must be null if mode is 'standard' or 'parent") if $organismAbbrev || $taxonId;
  }

  open my $fh, '<', $psqlFilePath or $self->error("error opening $psqlFilePath: $!");
  my $sqls = do { local $/; <$fh> };

  my $startTimeAll = time;
  # TODO: log timing info
  my @sqlList = split(/;\n\s*/, $sqls);
  foreach my $sql (@sqlList) {
    my $startTime = time;

    # for child we do not create indexes on the denorm table
    next if ($sql =~ /create.+index.+\n?.+on\s+(\:SCHEMA.:ORG_ABBREV)?$tableName\s/i) && mode eq 'child';

    my $newSql = instantiateSql($tableName, $schema, $organismAbbrev, $mode);
    $self->log($commitMode? "FOR REAL" : "TEST ONLY" . " - SQL: \n$newSql\n\n");
    if ($commitMode) {
      $dbh->do($newSql);
    }
    $self->log("INDVIDUAL SQL TIME (sec): " . time - $startTime);
  }
  $self->log("TOTAL SQL TIME (sec) for table $tableName: " . time - $startTimeAll);
}

sub instantiateSql {
  my ($tableName, $schema, $organismAbbrev, $mode) = @_;

  if ($mode eq 'parent') {
    $newSql =~ s/\:CREATE_AND_POPULATE/CREATE TABLE $schema.$tableName AS /g;
    $newSql =~ s/\:DECLARE_PARTITION/partition by list (organismAbbrev)/g;
  } elsif ($mode eq 'child') {

    my $s = "
create table :SCHEMA.:ORG_ABBREVmy_table
partition of my_table
for values in (':ORG_ABBREV');

insert into :SCHEMA.:ORG_ABBREVmy_table from
";
    $newSql =~ s/\:CREATE_AND_POPULATE/$s/g;
    $newSql =~ s/\:DECLARE_PARTITION//g;
  }
  $newSql =~ s/\:TAXON_ID/$taxonId/g;
  $newSql =~ s/\:ORG_ABBREV/$organismAbbrev/g;
  $newSql =~ s/\:SCHEMA/$schema/g;
  return $newSql;
}

sub undoPreprocess {
  my($self, $dbh, $rowAlgInvocationList) = @_;

  $self->error("Expected a single rowAlgInvocationId") if scalar(@$rowAlgInvocationList) != 1;

  my $fileNames = $self->getAlgorithmParam($dbh, $rowAlgInvocationList, $PSQL_FILE_ARG);
  my $schemas = $self->getAlgorithmParam($dbh, $rowAlgInvocationList, $SCHEMA_ARG);
  my $orgAbbrevs = $self->getAlgorithmParam($dbh, $rowAlgInvocationList, $ORG_ABBREV_ARG);

  my $filePath = $fileNames->[0];
  my $fileName = basename($filePath);
  my $schema = $schemas->[0];
  my $orgAbbrev = $orgAbbrevs->[0];

  $fileName =~ /(.+).psql/ or $self->error("Invalid file name $fileName");
  my $tableName = $1;

  my $sql = "drop table $schema.$orgAbbrev$tableName";
  $dbh->do($sql) || $self->error("Failed executing $sql");
  $self->log("Dropped $schema.$tableName");

}

sub undoTables {
  my ($self) = @_;

  return @{ $self->{_undo_tables} }
}

1;
