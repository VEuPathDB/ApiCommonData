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

1;
