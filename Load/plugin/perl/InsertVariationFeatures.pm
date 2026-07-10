package ApiCommonData::Load::Plugin::InsertVariationFeatures;
use lib "$ENV{GUS_HOME}/lib/perl";
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use warnings;

use GUS::PluginMgr::Plugin;
use GUS::Supported::GusConfig;
use ApiCommonData::Load::VariationLoader qw/
  variationFeatureColumns transcriptProductColumns variationEffectColumns
  transformVariationFeature transformTranscriptProduct transformVariationEffect
/;
use File::Temp qw/tempdir/;

sub getArgsDeclaration {
  return [
    fileArg({ name => 'inputDir', descr => 'mergeExperiments output dir with the .dat files',
              constraintFunc => undef, reqd => 1, isList => 0, mustExist => 1, format => 'directory' }),
    stringArg({ name => 'extDbRlsSpec', descr => 'ExternalDatabaseRelease spec, name|version',
                constraintFunc => undef, reqd => 1, isList => 0 }),
    stringArg({ name => 'organismAbbrev', descr => 'apidb.organism.abbrev to scope the transcript lookup',
                constraintFunc => undef, reqd => 1, isList => 0 }),
    stringArg({ name => 'targetSchema', descr => 'schema to load into (default apidb; tests use jbrestel)',
                constraintFunc => undef, reqd => 0, isList => 0, default => 'apidb' }),
  ];
}

sub getDocumentation {
  my $purpose = "Load mergeExperiments variationFeature.dat, transcript_product.dat, and snpeff.dat into ApiDB variation tables in a single transaction.";
  return {
    purpose          => $purpose,
    purposeBrief     => $purpose,
    notes            => "Undo via undoPreprocess (no row_alg_invocation_id on these tables).",
    tablesAffected   => "ApiDB.VariationFeature, ApiDB.VariationTranscriptProduct, ApiDB.VariationEffect",
    tablesDependedOn => "dots.Transcript, dots.ExternalNaSequence, apidb.Organism, sres.ExternalDatabaseRelease",
    howToRestart     => "Re-run; the load deletes existing rows for this external_database_release_id first.",
    failureCases     => "Unknown organismAbbrev; sequence id not in genome; transcript id unresolved for a coding effect.",
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

sub run { die "not yet implemented\n"; }

sub getTranscriptMap {
  my ($self, $organismAbbrev) = @_;
  my $dbh = $self->getQueryHandle();
  my $sql = "
    SELECT t.source_id, t.na_feature_id
    FROM   dots.Transcript t, dots.NaSequence ns, apidb.Organism o
    WHERE  t.na_sequence_id = ns.na_sequence_id
      AND  ns.taxon_id      = o.taxon_id
      AND  o.abbrev         = ?";
  my $sth = $dbh->prepare($sql);
  $sth->execute($organismAbbrev);
  my %map;
  while (my ($sid, $nfid) = $sth->fetchrow_array) { $map{$sid} = $nfid; }
  $self->error("No transcripts found for organismAbbrev '$organismAbbrev' - is it loaded?")
    unless %map;
  $self->log("Loaded " . scalar(keys %map) . " transcript ids for $organismAbbrev");
  return \%map;
}

sub getGenomicSequenceIds {
  my ($self, $organismAbbrev) = @_;
  my $dbh = $self->getQueryHandle();
  my $sql = "
    SELECT ens.source_id
    FROM   dots.ExternalNaSequence ens, apidb.Organism o
    WHERE  ens.taxon_id = o.taxon_id
      AND  o.abbrev     = ?";
  my $sth = $dbh->prepare($sql);
  $sth->execute($organismAbbrev);
  my %seqIds;
  while (my ($sid) = $sth->fetchrow_array) { $seqIds{$sid} = 1; }
  return \%seqIds;
}

# Reads distinct seq_id (column 2) from variationFeature.dat and dies if any is
# not a genomic sequence for this organism. Nothing else protects
# VariationFeature.sequence_source_id (it is a bare VARCHAR with no FK).
sub validateSequenceIds {
  my ($self, $inputDir, $validSeqIds) = @_;
  open(my $fh, '<', "$inputDir/variationFeature.dat")
    or $self->error("Cannot open $inputDir/variationFeature.dat: $!");
  <$fh>; # header
  my %seen;
  while (my $line = <$fh>) {
    chomp $line;
    my @f = split /\t/, $line, -1;
    $seen{$f[1]} = 1;
  }
  close $fh;
  my @bad = grep { !$validSeqIds->{$_} } sort keys %seen;
  $self->error("variationFeature.dat references sequence ids not in this organism's genome: "
    . join(", ", @bad)) if @bad;
  $self->log("Validated " . scalar(keys %seen) . " distinct sequence ids");
}

# Parse host/port/dbname out of the gus.config dbiDsn. NOTE: the port matters —
# the default config runs on 5433, and psql defaults to 5432, so an omitted port
# silently hits the wrong database.
sub getPsqlConnection {
  my ($self) = @_;
  my $cfg = GUS::Supported::GusConfig->new();
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
# Psql.pm and is verified against this data (no backticks, double quotes, or CRs
# occur in any field); the data is unquoted so QUOTE only needs a byte that
# never appears.
sub copyCommand {
  my ($self, $table, $columns, $file) = @_;
  my $cols = join(", ", @$columns);
  return "\\copy $table ($cols) FROM '$file' "
       . "WITH (FORMAT CSV, DELIMITER E'\\t', QUOTE '`', ENCODING 'UTF8')";
}

sub loadAll {
  my ($self, $schema, $extDbRlsId, $vfFile, $tpFile, $veFile) = @_;
  my $conn = $self->getPsqlConnection();
  my $dir  = tempdir(CLEANUP => 1);
  my $sqlFile = "$dir/load.sql";

  open(my $sql, '>', $sqlFile) or $self->error("Cannot write $sqlFile: $!");
  print $sql "BEGIN;\n";
  print $sql "DELETE FROM $schema.VariationFeature WHERE external_database_release_id = $extDbRlsId;\n";
  print $sql $self->copyCommand("$schema.VariationFeature",           variationFeatureColumns(),  $vfFile) . "\n";
  print $sql $self->copyCommand("$schema.VariationTranscriptProduct", transcriptProductColumns(), $tpFile) . "\n";
  print $sql $self->copyCommand("$schema.VariationEffect",            variationEffectColumns(),   $veFile) . "\n";
  print $sql "COMMIT;\n";
  close $sql;

  my $connStr = "postgresql://$conn->{login}:$conn->{password}\@$conn->{host}:$conn->{port}/$conn->{dbname}";
  my $logFile = "$dir/psql.log";
  my $cmd = "psql -v ON_ERROR_STOP=1 --log-file='$logFile' -f '$sqlFile' '$connStr'";

  $self->log("Running single-transaction load via psql");
  my $rc = system($cmd);
  if ($rc != 0) {
    $self->printFile($logFile);
    $self->error("psql load failed (rc=$rc); transaction rolled back, prior data intact");
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
