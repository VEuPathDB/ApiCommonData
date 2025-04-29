
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

The following values are passed in to the psql as macro values:
 - :SCHEMA     - the schema where denormalized tables are made
 - :ALG_INV_ID - algorithm invocation (for undo)
 - :TAXON_ID - taxon_id, if organism specific
 - :CREATE_OR_INSERT - a CREATE TABLE AS or a INSERT FROM clause, depending on the mode we're running in.  (only used for organism specific)
 - :SUFFIX - to make temp tables unique.  

We rely on postgres-specific syntax (IF EXISTS), so this is not oracle compatible.

A typical file might look like this:
create table MY_TMP_TABLE_1:SUFFIX as (select ...)  -- use plugin-supplied suffix (timestamp) to avoid collisions with other plugins
create table MY_TMP_TABLE_2:SUFFIX as (select ...)
&operation (select ...)         -- operation is one of: CREATE TABLE AS or INSERT FROM. insert uses &algInvId macro to mark rows for future undo
create index MY_DENORM_IX if not exists
drop table MY_TMP_TABLE_1:SUFFIX
drop table MY_TMP_TABLE_2:SUFFIX

The plugin runs in one of two modes:
 - create
 - insert

Create mode uses "create table MY_DENORM_TABLE as" for the operation.  this is used for comparative tables and for organism-specific tables
before the organism graph.  In the latter case we pass in a fictitious organism to force creation of an empty table.  Thus before the
organism specific graphs are run we expect an empty table to exist.

Insert mode is for organism-specific graphs.  It first runs a "select count (*) where organismAbbrev = " query to ensure that the target table does not have
rows for this organism.   Then it runs a "insert into MY_DENORM_TABLE from" to populate the table

The undo logic is custom.  It acquires the plugin arg values, and from those infers MY_DENORM_TABLE, and other args.  If the plugin was
run in creation mode, the undo drops the table.  Otherwise it clears out the rows for this alg_inv_id
PLUGIN_NOTES

my $documentation = { purpose=>$purpose,
		      purposeBrief=>$purposeBrief,
		      tablesAffected=>$tablesAffected,
		      tablesDependedOn=>$tablesDependedOn,
		      howToRestart=>$howToRestart,
		      failureCases=>$failureCases,
		      notes=>$notes
		    };

my $MODE_ARG = 'mode';
my $PSQL_FILE_ARG = 'psqlFile';
my $SCHEMA_ARG = 'schema';

my $argsDeclaration =
  [
   enumArg({ name => $MODE_ARG,
	     descr => '',
	     constraintFunc => undef,
	     reqd => 1,
	     isList => 0,
	     enum => 'create, insert'
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
   stringArg({name => 'organismAbbrev',
	      descr => 'internal organism abbrev, if this table has organism specific rows',
	      constraintFunc => undef,
	      reqd => 0,
	      isList => 0
	     }),
   stringArg({name => 'taxonId',
	      descr => 'used as filter in the sql, if this table has organism specific rows',
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
  my ($self) = @_;
  my $psqlFilePath = $self->getArg('psqlFile');
  my $schema = $self->getArg('schema');
  my $projectId = $self->getArg('projectId');
  my $organismAbbrev = $self->getArg('organismAbbrev');
  my $mode = $self->getArg('mode');
  my $taxonId = $self->getArg('taxonId');
  my $algInvId   = $self->getAlgInvocation()->getId();

  my $dbh = $self->getQueryHandle();
  $dbh->{RaiseError} = 1;
  $dbh->{AutoCommit} = 1;
  my $commitMode = $self->getArg('commit');

  my $fileName = basename($psqlFilePath);
  $fileName =~ /(.+).psql/ or $self->error("psqlFile name must be in form MY_DENORM_TABLE.psql");
  my $tableName = $1;
  my $suffix = "_" . $tableName.$organismAbbrev.time;  # unique suffix for this run.

  if ($mode eq 'insert') {
    $self->error("organismAbbrev and taxonId are required args if mode is 'insert'") unless $organismAbbrev && $taxonId;
    checkForPreviousRows("$schema.$tableName", $organismAbbrev, $dbh);
  }

  open my $fh, '<', $psqlFilePath or $self->error("error opening $psqlFilePath: $!");
  my $sqls = do { local $/; <$fh> };

  my @sqlList = split(/;\n\s*/, $sqls);
  foreach my $sql (@sqlList) {
    my $newSql = $sql;
    $newSql =~ s/\:ALG_INV_ID/$algInvId/g;
    $newSql =~ s/\:TAXON_ID/$taxonId/g;
    $newSql =~ s/\:SCHEMA/$schema/g;
    $newSql =~ s/\:SUFFIX/$suffix/g;
    if ($mode eq 'create') {
      $newSql =~ s/\:CREATE_OR_INSERT/CREATE TABLE $schema.$tableName AS /g;
    } else {
      $newSql =~ s/\:CREATE_OR_INSERT/INSERT INTO $schema.$tableName /g;
    }
    $self->log($commitMode? "FOR REAL" : "TEST ONLY" . " - SQL: \n$newSql\n\n");
    if ($commitMode) {
      $dbh->do($newSql);
    }
  }
}

sub undoPreprocess {
  my($self, $dbh, $rowAlgInvocationList) = @_;

  $self->error("Expected a single rowAlgInvocationId") if scalar(@$rowAlgInvocationList) != 1;

  my $modes = $self->getAlgorithmParam($dbh, $rowAlgInvocationList, $MODE_ARG);
  my $fileNames = $self->getAlgorithmParam($dbh, $rowAlgInvocationList, $PSQL_FILE_ARG);
  my $schemas = $self->getAlgorithmParam($dbh, $rowAlgInvocationList, $SCHEMA_ARG);

  my $mode = $modes->[0];
  my $filePath = $fileNames->[0];
  my $fileName = basename($filePath);
  my $schema = $schemas->[0];

  $fileName =~ /(.+).psql/ or $self->error("Invalid file name $fileName");
  my $tableName = $1;

  if ($mode eq 'insert') {
     $self->{_undo_tables} = ["$schema.$tableName"];
  } elsif ($mode eq 'create') {
    my $sql = "drop table $schema.$tableName";
    $dbh->do($sql) || $self->error("Failed executing $sql");
    $self->log("Dropped $schema.$tableName");
  } else {
    $self->error("Invalid mode param: $mode");
  }
}

sub undoTables {
  my ($self) = @_;

  return @{ $self->{_undo_tables} }
}

1;
