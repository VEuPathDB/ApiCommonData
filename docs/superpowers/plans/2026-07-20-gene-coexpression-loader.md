# InsertGeneCoexpression Loader Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Load a 3-column (gene_id, associated_gene_id, coefficient) input file into `ApiDB.GeneCoexpression` via a single-transaction `psql \copy`, stamping every row with the `external_database_release_id` resolved from a command-line `extDbRlsSpec`.

**Architecture:** Split responsibilities, mirroring the `variation-dat-loader` branch. `ApiCommonData::Load::GeneCoexpressionLoader` is a pure module (no GUS, no DBI) owning the canonical copy column order and the file transform — unit-testable without a database. `ApiCommonData::Load::Plugin::InsertGeneCoexpression` is the GUS plugin that resolves the external database release, calls the transform, assembles one SQL script (`BEGIN; DELETE; \copy; COMMIT;`), and runs `psql -f` once. Undo is via the `undoPreprocess` hook (`undoTables` cannot work — no `row_alg_invocation_id` on this table). The plugin's load core (`validSchema`, `getPsqlConnection`, `copyCommand`, `loadAll`, `printFile`, `undoPreprocess`, `getAlgorithmParam`) is carried over verbatim from the already-reviewed `InsertVariationFeatures`.

**Tech Stack:** Perl 5, GUS PluginMgr, PostgreSQL `\copy` via the `psql` CLI, `Test::More`/`Test::Exception`/`prove`.

**Spec:** `docs/superpowers/specs/2026-07-20-gene-coexpression-loader-design.md`

---

## Environment setup (run once per shell before building or running)

```bash
export PROJECT_HOME=/home/jbrestel/workspaces/dataLoad/project_home
export GUS_HOME=/home/jbrestel/workspaces/dataLoad/gus_home
export PATH=$GUS_HOME/bin:$PATH
export PERL5LIB=$GUS_HOME/lib/perl:/home/jbrestel/perl5/lib/perl5
```

**Module resolution (important — do not skip):** Source `.pm` files live *flat* under `Load/lib/perl/` (e.g. `Load/lib/perl/GeneCoexpressionLoader.pm`) but declare the full package `ApiCommonData::Load::GeneCoexpressionLoader`. Perl can only resolve that from a directory that has an `ApiCommonData/Load/` subtree — i.e. the **built** copy at `$GUS_HOME/lib/perl/ApiCommonData/Load/`. Therefore:

- Every `.t` file uses `use lib "$ENV{GUS_HOME}/lib/perl";` (matching all existing repo tests), **not** a `$PROJECT_HOME/...` path.
- After editing any `.pm`, sync it into the built tree before running tests or the plugin. Dev-loop sync (fast; what to use during this work):

  ```bash
  cp $PROJECT_HOME/ApiCommonData/Load/lib/perl/GeneCoexpressionLoader.pm \
     $GUS_HOME/lib/perl/ApiCommonData/Load/
  # plugin file, when it exists:
  cp $PROJECT_HOME/ApiCommonData/Load/plugin/perl/InsertGeneCoexpression.pm \
     $GUS_HOME/lib/perl/ApiCommonData/Load/Plugin/
  ```

  The full deploy build is `build ApiCommonData install ...` (heavyweight). Do **not** run it for this dev loop; the `cp` sync is standard GUS dev practice. The committed source is the source of truth; the `cp` is a local install step, never committed.

- `Test::Exception` is a repo test dependency. If missing, install once: `cpanm --local-lib=/home/jbrestel/perl5 Test::Exception`. The `PERL5LIB` above already includes `/home/jbrestel/perl5/lib/perl5`.

Unit tests (Tasks 1–2) need the `cp` sync but no DB. The integration test (Task 6) needs both the sync and a live database with a `jbrestel` stub table.

---

## File Structure

- Create: `Load/lib/perl/GeneCoexpressionLoader.pm` — pure column defs + transform.
- Create: `Load/plugin/perl/InsertGeneCoexpression.pm` — GUS plugin (args, run, load core, undo).
- Create: `Load/t/geneCoexpressionLoader.t` — unit tests (no DB).
- Create: `Load/t/insertGeneCoexpression_integration.t` — env-gated live-DB load test.

---

### Task 1: GeneCoexpressionLoader — column definitions

**Files:**
- Create: `Load/lib/perl/GeneCoexpressionLoader.pm`
- Test: `Load/t/geneCoexpressionLoader.t`

- [ ] **Step 1: Write the failing test**

Create `Load/t/geneCoexpressionLoader.t`:

```perl
use strict;
use warnings;
use lib "$ENV{GUS_HOME}/lib/perl";
use Test::More;
use Test::Exception;
use ApiCommonData::Load::GeneCoexpressionLoader qw/
  geneCoexpressionColumns transformGeneCoexpression
/;

# Canonical copy column order. gene_coexpression_id is intentionally absent
# (filled by the sequence default), so 4 columns, not 5.
is(scalar @{geneCoexpressionColumns()}, 4, 'GeneCoexpression copy list has 4 columns');
is_deeply(geneCoexpressionColumns(),
  [qw/gene_id associated_gene_id coefficient external_database_release_id/],
  'column order matches the copy target');

done_testing;
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd $PROJECT_HOME && prove -v ApiCommonData/Load/t/geneCoexpressionLoader.t
```
Expected: FAIL — `Can't locate ApiCommonData/Load/GeneCoexpressionLoader.pm`.

- [ ] **Step 3: Write minimal implementation**

Create `Load/lib/perl/GeneCoexpressionLoader.pm`:

```perl
package ApiCommonData::Load::GeneCoexpressionLoader;

use strict;
use warnings;

use Exporter 'import';
our @EXPORT_OK = qw/
  geneCoexpressionColumns transformGeneCoexpression
/;

# Canonical copy column order. The transform below emits values in exactly this
# order; the plugin uses this same list to build the \copy field list. Keep the
# two in lockstep — the unit test asserts the count. gene_coexpression_id is
# intentionally omitted so the sequence DEFAULT fills it.
sub geneCoexpressionColumns {
  return [ qw/ gene_id associated_gene_id coefficient external_database_release_id / ];
}

1;
```

- [ ] **Step 4: Sync and run test to verify it passes**

```bash
cp $PROJECT_HOME/ApiCommonData/Load/lib/perl/GeneCoexpressionLoader.pm \
   $GUS_HOME/lib/perl/ApiCommonData/Load/
cd $PROJECT_HOME && prove -v ApiCommonData/Load/t/geneCoexpressionLoader.t
```
Expected: PASS (2 subtests).

- [ ] **Step 5: Commit**

```bash
git add ApiCommonData/Load/lib/perl/GeneCoexpressionLoader.pm ApiCommonData/Load/t/geneCoexpressionLoader.t
git commit -m "feat: GeneCoexpressionLoader column defs"
```

---

### Task 2: GeneCoexpressionLoader — transformGeneCoexpression

**Files:**
- Modify: `Load/lib/perl/GeneCoexpressionLoader.pm`
- Test: `Load/t/geneCoexpressionLoader.t`

- [ ] **Step 1: Write the failing tests**

Insert these blocks into `Load/t/geneCoexpressionLoader.t` immediately before `done_testing;`:

```perl
use File::Temp qw/tempfile/;

# Helper: run the transform over an in-memory input string, return
# (row count, arrayref of output lines).
sub run_transform {
  my ($input, $extDbRlsId) = @_;
  my ($inFh, $inFile)   = tempfile(UNLINK => 1);
  my ($outFh, $outFile) = tempfile(UNLINK => 1);
  print $inFh $input; close $inFh;
  open(my $rh, '<', $inFile) or die $!;
  my $n = transformGeneCoexpression($rh, $outFh, $extDbRlsId);
  close $outFh; close $rh;
  open(my $oh, '<', $outFile) or die $!;
  my @lines = <$oh>; close $oh;
  chomp @lines;
  return ($n, \@lines);
}

my $HEADER = "gene_id\tassociated_gene_id\tcoefficient\n";

# Happy path: header skipped, extDbRlsId appended, two data rows.
{
  my ($n, $lines) = run_transform(
    $HEADER . "geneA\tgeneB\t0.91\n" . "geneA\tgeneC\t-0.42\n", 7);
  is($n, 2, 'two data rows transformed');
  is($lines->[0], "geneA\tgeneB\t0.91\t7", 'row 1: extDbRlsId appended');
  is($lines->[1], "geneA\tgeneC\t-0.42\t7", 'row 2: negative coefficient preserved');
  my @fields = split /\t/, $lines->[0], -1;
  is(scalar @fields, 4, 'output row has 4 fields');
}

# Empty file (no header).
throws_ok { run_transform("", 1) } qr/empty file/, 'dies on empty file';

# Wrong header column count.
throws_ok { run_transform("gene_id\tcoefficient\nx\ty\n", 1) }
  qr/expected 3 columns/, 'dies on 2-column header';

# Unexpected header names.
throws_ok { run_transform("a\tb\tc\nx\ty\tz\n", 1) }
  qr/unexpected header/, 'dies on wrong header names';

# Data line with wrong field count.
throws_ok { run_transform($HEADER . "geneA\tgeneB\n", 1) }
  qr/expected 3 fields/, 'dies on 2-field data line';

# Blank coefficient is a data error (schema allows NULL, this loader does not).
throws_ok { run_transform($HEADER . "geneA\tgeneB\t\n", 1) }
  qr/blank coefficient/, 'dies on blank coefficient';
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd $PROJECT_HOME && prove -v ApiCommonData/Load/t/geneCoexpressionLoader.t
```
Expected: FAIL — `transformGeneCoexpression` is not exported/defined (`Undefined subroutine`).

- [ ] **Step 3: Write minimal implementation**

Add `transformGeneCoexpression` to the `@EXPORT_OK` list and define the sub in `Load/lib/perl/GeneCoexpressionLoader.pm`, before the final `1;`. The `@EXPORT_OK` line becomes:

```perl
our @EXPORT_OK = qw/
  geneCoexpressionColumns transformGeneCoexpression
/;
```

(It already reads this way from Task 1 — leave it.) Add the sub:

```perl
# Read the input file handle, validate + skip the header, and for each data line
# write a tab-delimited output line with $extDbRlsId appended. Returns the row
# count. All failures die with a line number so the plugin can surface them
# before any load runs.
sub transformGeneCoexpression {
  my ($inFh, $outFh, $extDbRlsId) = @_;

  my $header = <$inFh>;
  die "geneCoexpression: empty file (no header)\n" unless defined $header;
  chomp $header;
  my @cols = split /\t/, $header, -1;
  die "geneCoexpression: expected 3 columns, got " . scalar(@cols) . "\n"
    unless @cols == 3;
  die "geneCoexpression: unexpected header (want gene_id, associated_gene_id, coefficient)\n"
    unless $cols[0] eq 'gene_id'
       &&  $cols[1] eq 'associated_gene_id'
       &&  $cols[2] eq 'coefficient';

  my $n = 0;
  while (my $line = <$inFh>) {
    chomp $line;
    my @f = split /\t/, $line, -1;
    die "geneCoexpression line $.: expected 3 fields, got " . scalar(@f) . "\n"
      unless @f == 3;
    die "geneCoexpression line $.: blank coefficient\n" if $f[2] eq '';
    print $outFh join("\t", $f[0], $f[1], $f[2], $extDbRlsId), "\n";
    $n++;
  }
  return $n;
}
```

- [ ] **Step 4: Sync and run tests to verify they pass**

```bash
cp $PROJECT_HOME/ApiCommonData/Load/lib/perl/GeneCoexpressionLoader.pm \
   $GUS_HOME/lib/perl/ApiCommonData/Load/
cd $PROJECT_HOME && prove -v ApiCommonData/Load/t/geneCoexpressionLoader.t
```
Expected: PASS (all subtests, including the 6 error cases).

- [ ] **Step 5: Commit**

```bash
git add ApiCommonData/Load/lib/perl/GeneCoexpressionLoader.pm ApiCommonData/Load/t/geneCoexpressionLoader.t
git commit -m "feat: transformGeneCoexpression (validate header, append extDbRlsId)"
```

---

### Task 3: InsertGeneCoexpression — plugin skeleton (args + docs)

**Files:**
- Create: `Load/plugin/perl/InsertGeneCoexpression.pm`

- [ ] **Step 1: Write the plugin skeleton**

Create `Load/plugin/perl/InsertGeneCoexpression.pm`:

```perl
package ApiCommonData::Load::Plugin::InsertGeneCoexpression;
use lib "$ENV{GUS_HOME}/lib/perl";
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use warnings;

use GUS::PluginMgr::Plugin;
use GUS::Supported::GusConfig;
use ApiCommonData::Load::GeneCoexpressionLoader qw/
  geneCoexpressionColumns transformGeneCoexpression
/;
use File::Temp qw/tempdir/;

sub getArgsDeclaration {
  return [
    fileArg({ name => 'inputFile', descr => 'tab-delimited file: gene_id, associated_gene_id, coefficient (with header)',
              constraintFunc => undef, reqd => 1, isList => 0, mustExist => 1, format => 'file' }),
    stringArg({ name => 'extDbRlsSpec', descr => 'ExternalDatabaseRelease spec, name|version',
                constraintFunc => undef, reqd => 1, isList => 0 }),
    stringArg({ name => 'targetSchema', descr => 'schema to load into (default apidb)',
                constraintFunc => undef, reqd => 0, isList => 0, default => 'apidb' }),
  ];
}

sub getDocumentation {
  my $purpose = "Load gene coexpression pairs (gene_id, associated_gene_id, coefficient) into ApiDB.GeneCoexpression in a single transaction.";
  return {
    purpose          => $purpose,
    purposeBrief     => $purpose,
    notes            => "Undo via undoPreprocess (no row_alg_invocation_id on this table).",
    tablesAffected   => "ApiDB.GeneCoexpression",
    tablesDependedOn => "sres.ExternalDatabaseRelease",
    howToRestart     => "Re-run; the load deletes existing rows for this external_database_release_id first.",
    failureCases     => "Unresolvable extDbRlsSpec; malformed header; wrong field count; blank coefficient.",
  };
}

sub new {
  my $class = shift;
  my $self = {};
  bless($self, $class);
  $self->initialize({
    requiredDbVersion => 4.0,
    cvsRevision       => '$Revision$',
    name              => ref($self),
    argsDeclaration   => getArgsDeclaration(),
    documentation     => getDocumentation(),
  });
  return $self;
}

1;
```

- [ ] **Step 2: Sync and syntax-check**

```bash
cp $PROJECT_HOME/ApiCommonData/Load/plugin/perl/InsertGeneCoexpression.pm \
   $GUS_HOME/lib/perl/ApiCommonData/Load/Plugin/
perl -c $GUS_HOME/lib/perl/ApiCommonData/Load/Plugin/InsertGeneCoexpression.pm
```
Expected: `... syntax OK`.

- [ ] **Step 3: Commit**

```bash
git add ApiCommonData/Load/plugin/perl/InsertGeneCoexpression.pm
git commit -m "feat: InsertGeneCoexpression plugin skeleton (args, docs)"
```

---

### Task 4: InsertGeneCoexpression — run() + load core

**Files:**
- Modify: `Load/plugin/perl/InsertGeneCoexpression.pm`

These methods are carried over verbatim from the reviewed `InsertVariationFeatures`, adapted to the single file / single table. Add them before the final `1;`.

- [ ] **Step 1: Add run() and the load core**

```perl
sub run {
  my ($self) = @_;

  my $inputFile  = $self->getArg('inputFile');
  my $schema     = $self->validSchema($self->getArg('targetSchema'));
  my $extDbRlsId = $self->getExtDbRlsId($self->getArg('extDbRlsSpec'))
    or $self->error("Cannot resolve extDbRlsSpec: " . $self->getArg('extDbRlsSpec'));

  my $dir     = tempdir(CLEANUP => 1);
  my $tmpFile = "$dir/coexpression.tmp";

  my $n = $self->transformInput($inputFile, $tmpFile, $extDbRlsId);
  $self->loadAll($schema, $extDbRlsId, $tmpFile);

  return "Loaded GeneCoexpression=$n";
}

sub transformInput {
  my ($self, $inputFile, $outFile, $extDbRlsId) = @_;
  open(my $in,  '<', $inputFile) or $self->error("Cannot open $inputFile: $!");
  open(my $out, '>', $outFile)   or $self->error("Cannot write $outFile: $!");
  my $n = eval { transformGeneCoexpression($in, $out, $extDbRlsId) };
  my $err = $@;
  close $in;
  # Check close on the OUTPUT handle: a failed flush (e.g. disk full) would
  # silently truncate the temp file, and the reported count would still be $n.
  my $closedOk = close $out;
  $self->error("Transform of $inputFile failed: $err") if $err;
  $self->error("Failed to flush/close $outFile (write may be incomplete): $!") unless $closedOk;
  $self->log("Transformed $inputFile: $n rows");
  return $n;
}

# Guard a schema name before interpolating it into SQL. targetSchema is an
# operator-supplied bare identifier (default 'apidb'); reject anything that
# isn't a plain identifier so it can never carry SQL.
sub validSchema {
  my ($self, $schema) = @_;
  $self->error("Invalid schema name '$schema' (expected a bare identifier)")
    unless defined $schema && $schema =~ /^\w+$/;
  return $schema;
}

# Parse host/port/dbname out of the gus.config dbiDsn. NOTE: the port matters —
# the default config runs on 5433, and psql defaults to 5432, so an omitted port
# silently hits the wrong database.
sub getPsqlConnection {
  my ($self) = @_;
  my $gusConfigFile = $self->getArg('gusConfigFile');
  my $cfg = $gusConfigFile
    ? GUS::Supported::GusConfig->new($gusConfigFile)
    : GUS::Supported::GusConfig->new();

  my $dsn = $cfg->getDbiDsn();     # dbi:Pg:dbname=...;host=...;port=...
  my ($dbname) = $dsn =~ /dbname=([^;]+)/;
  my ($host)   = $dsn =~ /host=([^;]+)/;
  my ($port)   = $dsn =~ /port=([^;]+)/;
  return {
    login    => $cfg->getDatabaseLogin(),
    password => $cfg->getDatabasePassword(),
    dbname   => $dbname,
    host     => $host || 'localhost',
    port     => $port || 5432,
  };
}

# Build a single-line \copy command. Psql.pm's getCommand() emits multi-line,
# which fails in a psql -f script, so we assemble it here. QUOTE '`' matches
# Psql.pm; the data is unquoted so QUOTE only needs a byte that never appears
# in gene ids or coefficients.
sub copyCommand {
  my ($self, $table, $columns, $file) = @_;
  my $cols = join(", ", @$columns);
  return "\\copy $table ($cols) FROM '$file' "
       . "WITH (FORMAT CSV, DELIMITER E'\\t', QUOTE '`', ENCODING 'UTF8')";
}

sub loadAll {
  my ($self, $schema, $extDbRlsId, $tmpFile) = @_;
  my $conn = $self->getPsqlConnection();
  my $dir  = tempdir(CLEANUP => 1);
  my $sqlFile = "$dir/load.sql";

  open(my $sql, '>', $sqlFile) or $self->error("Cannot write $sqlFile: $!");
  print $sql "BEGIN;\n";
  print $sql "DELETE FROM $schema.GeneCoexpression WHERE external_database_release_id = $extDbRlsId;\n";
  print $sql $self->copyCommand("$schema.GeneCoexpression", geneCoexpressionColumns(), $tmpFile) . "\n";
  print $sql "COMMIT;\n";
  close $sql;

  my $logFile = "$dir/psql.log";
  # List-form system() bypasses the shell entirely: no quoting, and no way for a
  # password or path containing shell metacharacters to be misparsed. The
  # password travels in the child's env (PGPASSWORD), never on the command line.
  local $ENV{PGPASSWORD} = $conn->{password};
  my @cmd = ('psql',
             '-h', $conn->{host}, '-p', $conn->{port},
             '-U', $conn->{login}, '-d', $conn->{dbname},
             '-v', 'ON_ERROR_STOP=1',
             '--log-file', $logFile,
             '-f', $sqlFile);

  $self->log("Running single-transaction load via psql");
  my $rc = system(@cmd);
  if ($rc != 0) {
    $self->printFile($logFile);
    my $exit = ($rc == -1) ? -1 : ($rc >> 8);   # decode wait status to exit code
    $self->error("psql load failed (exit=$exit); transaction rolled back, prior data intact");
  }
}

sub printFile {
  my ($self, $file) = @_;
  return unless -e $file;
  open(my $fh, '<', $file) or return;
  while (<$fh>) { $self->log("psql: $_") }
  close $fh;
}
```

- [ ] **Step 2: Sync and syntax-check**

```bash
cp $PROJECT_HOME/ApiCommonData/Load/plugin/perl/InsertGeneCoexpression.pm \
   $GUS_HOME/lib/perl/ApiCommonData/Load/Plugin/
perl -c $GUS_HOME/lib/perl/ApiCommonData/Load/Plugin/InsertGeneCoexpression.pm
```
Expected: `... syntax OK`.

- [ ] **Step 3: Commit**

```bash
git add ApiCommonData/Load/plugin/perl/InsertGeneCoexpression.pm
git commit -m "feat: InsertGeneCoexpression run() + single-transaction psql load core"
```

---

### Task 5: InsertGeneCoexpression — undo

**Files:**
- Modify: `Load/plugin/perl/InsertGeneCoexpression.pm`

`GeneCoexpression` has no `row_alg_invocation_id`, so the standard `undoTables` mechanism cannot work. Undo is done in `undoPreprocess`, recovering `extDbRlsSpec` (and optional `targetSchema`) from `core.AlgorithmParam` and deleting by resolved id. Carried over verbatim from `InsertVariationFeatures`, adapted to this table. Add before the final `1;`.

- [ ] **Step 1: Add the undo methods**

```perl
sub undoTables { return (); }   # no row_alg_invocation_id on this table

sub undoPreprocess {
  my ($self, $dbh, $rowAlgInvocationList) = @_;

  my $specs = $self->getAlgorithmParam($dbh, $rowAlgInvocationList, 'extDbRlsSpec');
  $self->error("undo: could not recover extDbRlsSpec from core.AlgorithmParam")
    unless $specs && @$specs;

  # targetSchema is optional; default to apidb if it was not recorded.
  my $schemas = $self->getAlgorithmParam($dbh, $rowAlgInvocationList, 'targetSchema');
  my $schema  = ($schemas && @$schemas && $schemas->[0]) ? $schemas->[0] : 'apidb';
  $schema = $self->validSchema($schema);

  foreach my $spec (@$specs) {
    my ($name, $version) = split /\|/, $spec;
    my $sql = "
      SELECT r.external_database_release_id
      FROM   sres.ExternalDatabaseRelease r, sres.ExternalDatabase d
      WHERE  d.external_database_id = r.external_database_id
        AND  d.name = ? AND r.version = ?";
    my $sth = $dbh->prepare($sql);
    $sth->execute($name, $version);
    my ($id) = $sth->fetchrow_array;
    $self->error("undo: no external_database_release_id for '$spec'") unless $id;

    my $del = $dbh->prepare("DELETE FROM $schema.GeneCoexpression WHERE external_database_release_id = ?");
    my $n = $del->execute($id);
    $self->log("undo: deleted $n GeneCoexpression rows for $spec");
  }
}

# Recover a plugin argument's recorded value(s) from core.AlgorithmParam, keyed
# by plugin name and invocation id. Pattern from InsertVariationFeatures.
sub getAlgorithmParam {
  my ($self, $dbh, $rowAlgInvocationList, $paramKey) = @_;
  my $pluginName = ref($self);
  my @values;
  foreach my $rowAlgInvId (@$rowAlgInvocationList) {
    my $sql = "SELECT p.STRING_VALUE
      FROM core.ALGORITHMPARAMKEY k
      LEFT JOIN core.ALGORITHMIMPLEMENTATION a ON k.ALGORITHM_IMPLEMENTATION_ID = a.ALGORITHM_IMPLEMENTATION_ID
      LEFT JOIN core.ALGORITHMPARAM p ON k.ALGORITHM_PARAM_KEY_ID = p.ALGORITHM_PARAM_KEY_ID
      WHERE a.EXECUTABLE = ? AND p.ROW_ALG_INVOCATION_ID = ? AND k.ALGORITHM_PARAM_KEY = ?";
    my $sth = $dbh->prepare($sql);
    $sth->execute($pluginName, $rowAlgInvId, $paramKey);
    while (my ($v) = $sth->fetchrow_array) { push @values, $v if defined $v; }
  }
  return \@values;
}
```

- [ ] **Step 2: Sync and syntax-check**

```bash
cp $PROJECT_HOME/ApiCommonData/Load/plugin/perl/InsertGeneCoexpression.pm \
   $GUS_HOME/lib/perl/ApiCommonData/Load/Plugin/
perl -c $GUS_HOME/lib/perl/ApiCommonData/Load/Plugin/InsertGeneCoexpression.pm
```
Expected: `... syntax OK`.

- [ ] **Step 3: Commit**

```bash
git add ApiCommonData/Load/plugin/perl/InsertGeneCoexpression.pm
git commit -m "feat: InsertGeneCoexpression undo via undoPreprocess"
```

---

### Task 6: Integration test (env-gated, live DB)

**Files:**
- Create: `Load/t/insertGeneCoexpression_integration.t`

This test is off by default. It loads into a `jbrestel` stub schema via psql, exercising the exact `\copy` command shape the plugin uses, and verifies that a reload replaces (not duplicates) rows for the same `external_database_release_id`. It requires a `<schema>.GeneCoexpression` table to exist (create it from `createGeneCoexpression.sql` under the `jbrestel` schema, or point `GENECOEXP_DB_SCHEMA` at a schema that has it).

- [ ] **Step 1: Write the test**

Create `Load/t/insertGeneCoexpression_integration.t`:

```perl
use strict;
use warnings;
use lib "$ENV{GUS_HOME}/lib/perl";
use Test::More;
use File::Temp qw/tempdir/;
use ApiCommonData::Load::GeneCoexpressionLoader qw/
  geneCoexpressionColumns transformGeneCoexpression
/;

# Off by default: this test loads into a live Postgres via psql. Enable with
# GENECOEXP_DB_TEST=1. Connection is taken from the environment so it is not
# pinned to any one developer's box.
plan skip_all => "set GENECOEXP_DB_TEST=1 to run the live-DB integration test"
  unless $ENV{GENECOEXP_DB_TEST};

my $HOST   = $ENV{GENECOEXP_DB_HOST}   || 'localhost';
my $PORT   = $ENV{GENECOEXP_DB_PORT}   || '5432';
my $DB     = $ENV{GENECOEXP_DB_NAME}   || 'unidb_shu_a';
my $SCHEMA = $ENV{GENECOEXP_DB_SCHEMA} || 'jbrestel';
my $EXTDB  = $ENV{GENECOEXP_EXTDBRLS}  || 1;      # external_database_release_id to stamp
my $PSQL   = "psql -h $HOST -p $PORT -d $DB";

# Sample input: header + 3 rows (incl. a negative coefficient).
my $dir = tempdir(CLEANUP => 1);
my $inFile  = "$dir/coexpression.txt";
my $tmpFile = "$dir/coexpression.tmp";
open(my $w, '>', $inFile) or die $!;
print $w "gene_id\tassociated_gene_id\tcoefficient\n";
print $w "geneA\tgeneB\t0.91\n";
print $w "geneA\tgeneC\t-0.42\n";
print $w "geneB\tgeneC\t0.10\n";
close $w;

open(my $in,  '<', $inFile)  or die $!;
open(my $out, '>', $tmpFile) or die $!;
my $n = transformGeneCoexpression($in, $out, $EXTDB);
close $in; close $out;
is($n, 3, 'three data rows transformed');

my $cols = join(", ", @{geneCoexpressionColumns()});

sub load_once {
  my $sqlFile = "$dir/load.sql";
  open(my $s, '>', $sqlFile) or die $!;
  print $s "BEGIN;\n";
  print $s "DELETE FROM $SCHEMA.GeneCoexpression WHERE external_database_release_id = $EXTDB;\n";
  print $s "\\copy $SCHEMA.GeneCoexpression ($cols) FROM '$tmpFile' WITH (FORMAT CSV, DELIMITER E'\\t', QUOTE '`', ENCODING 'UTF8')\n";
  print $s "COMMIT;\n";
  close $s;
  return system("$PSQL -v ON_ERROR_STOP=1 -f '$sqlFile' >/dev/null 2>&1");
}

sub count_rows {
  my $c = `$PSQL -tAc "SELECT count(*) FROM $SCHEMA.GeneCoexpression WHERE external_database_release_id = $EXTDB"`;
  chomp $c; return $c;
}

is(load_once(), 0, 'first load succeeded');
is(count_rows(), 3, 'three rows present after first load');

# Reload must REPLACE, not duplicate (the DELETE-first restart contract).
is(load_once(), 0, 'reload succeeded');
is(count_rows(), 3, 'still three rows after reload (delete-first, no duplicates)');

# Coefficient round-trips, including the negative value.
my $coef = `$PSQL -tAc "SELECT coefficient FROM $SCHEMA.GeneCoexpression WHERE external_database_release_id = $EXTDB AND gene_id = 'geneA' AND associated_gene_id = 'geneC'"`;
chomp $coef;
is($coef + 0, -0.42, 'negative coefficient round-trips');

# Cleanup so the test is repeatable.
system("$PSQL -c 'DELETE FROM $SCHEMA.GeneCoexpression WHERE external_database_release_id = $EXTDB' >/dev/null 2>&1");
is(count_rows(), 0, 'cleanup deleted the test rows');

done_testing;
```

- [ ] **Step 2: Run it disabled (default), verify it skips cleanly**

```bash
cd $PROJECT_HOME && prove -v ApiCommonData/Load/t/insertGeneCoexpression_integration.t
```
Expected: `SKIP ... set GENECOEXP_DB_TEST=1` — passes as a skip.

- [ ] **Step 3: Run it enabled against the jbrestel stub schema**

Prerequisite: a `jbrestel.GeneCoexpression` table exists (ask John before creating tables in his schema, per his DB rules). Then:

```bash
cd $PROJECT_HOME && GENECOEXP_DB_TEST=1 GENECOEXP_DB_SCHEMA=jbrestel \
  prove -v ApiCommonData/Load/t/insertGeneCoexpression_integration.t
```
Expected: PASS — 3 rows loaded, reload still 3, negative coefficient round-trips, cleanup to 0.

- [ ] **Step 4: Commit**

```bash
git add ApiCommonData/Load/t/insertGeneCoexpression_integration.t
git commit -m "test: InsertGeneCoexpression env-gated integration load"
```

---

## Verification (end-to-end, after all tasks)

- [ ] Unit tests green: `cd $PROJECT_HOME && prove -v ApiCommonData/Load/t/geneCoexpressionLoader.t`
- [ ] Plugin compiles: `perl -c $GUS_HOME/lib/perl/ApiCommonData/Load/Plugin/InsertGeneCoexpression.pm`
- [ ] Plugin self-documents: `ga ApiCommonData::Load::Plugin::InsertGeneCoexpression --help` renders args + documentation without error.
- [ ] Integration test passes when enabled against a schema that has the table.
- [ ] `git log --oneline` shows the six focused commits on the `gene-coexpression-loader` branch; `master` is untouched.

## Notes / gotchas

- **Column list ↔ transform order:** `geneCoexpressionColumns()` and the fields `transformGeneCoexpression` emits must stay in lockstep. The unit test asserts the count (4); if you change one, change both.
- **`gene_coexpression_id` is not in the copy list** — the sequence `DEFAULT` fills it. Do not add it.
- **psql port:** the default gus.config runs on 5433; an omitted port silently hits 5432. `getPsqlConnection` carries this note.
- **No ID validation by design:** bad `gene_id`/`associated_gene_id` load silently (the schema has no FK on them). This was an explicit decision, not an oversight.
