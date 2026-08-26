package ApiCommonData::Load::Plugin::AnalyzePartitionedTables;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use File::Basename;
use GUS::PluginMgr::Plugin;

my $purposeBrief = <<PURPOSEBRIEF;
Analyze all partitioned parent tables in the webready schema.
PURPOSEBRIEF

my $purpose = <<PLUGIN_PURPOSE;
Analyze all partitioned parent tables in the webready schema.
PLUGIN_PURPOSE

my $tablesAffected = [];

my $tablesDependedOn = [];

my $howToRestart = <<PLUGIN_RESTART;
PLUGIN_RESTART

my $failureCases = <<PLUGIN_FAILURE_CASES;
None.
PLUGIN_FAILURE_CASES

my $notes = <<PLUGIN_NOTES;
This plugin analyzes all partitioned parent tables as a final step before cloning. This is needed to make sure the query
planner can make informed decisions when we don't use partition filters.
There's nothing to undo so undo is a noop.
PLUGIN_NOTES

my $documentation = { purpose=>$purpose,
		      purposeBrief=>$purposeBrief,
		      tablesAffected=>$tablesAffected,
		      tablesDependedOn=>$tablesDependedOn,
		      howToRestart=>$howToRestart,
		      failureCases=>$failureCases,
		      notes=>$notes
		    };

my $SCHEMA_ARG = 'schema';

my $argsDeclaration =
  [
    stringArg({name => $SCHEMA_ARG,
	      descr => 'schema to hold MY_DENOM_TABLE and temp tables',
	      constraintFunc => undef,
	      reqd => 1,
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

  my $schema = $self->getArg($SCHEMA_ARG);

  my $dbh = $self->getQueryHandle();
  $dbh->{RaiseError} = 1;
  $dbh->{AutoCommit} = 1;

  $dbh->do("set role gus_w");

  $sql = <<SQL;
    DO \$\$
    DECLARE
        r        record;
        started  timestamptz;
    BEGIN
        FOR r IN
            SELECT n.nspname AS schema, c.relname AS tbl
            FROM pg_class c
            JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE c.relkind = 'p'
              AND n.nspname = '$schema'
              AND NOT EXISTS (SELECT 1 FROM pg_inherits i WHERE i.inhrelid = c.oid)
            ORDER BY c.relname
        LOOP
            started := clock_timestamp();
            RAISE NOTICE 'ANALYZE %.% ...', r.schema, r.tbl;
            EXECUTE format('ANALYZE %I.%I', r.schema, r.tbl);
            RAISE NOTICE '  done in %', clock_timestamp() - started;
        END LOOP;
    END \$\$;
SQL

  $self->log("Starting ANALYZE statement");

  $dbh->do($sql) || $self->error("Failed executing $sql");

  $self->log("ANALYZE has finished successfully");
}


sub undoTables {
  my ($self) = @_;

  return @{ $self->{_undo_tables} }
}

1;
