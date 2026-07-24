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

# NOTE: this deliberately re-assembles the same BEGIN/DELETE/\copy/COMMIT shape
# that the plugin's loadAll + copyCommand produce, rather than instantiating the
# GUS plugin (which needs a full PluginMgr bootstrap). Keep this in lockstep with
# InsertGeneCoexpression::loadAll/copyCommand — if that SQL shape changes, update
# it here too. (Mirrors the insertVariationFeatures integration test.)
sub load_once {
  my $sqlFile = "$dir/load.sql";
  open(my $s, '>', $sqlFile) or die $!;
  print $s "BEGIN;\n";
  print $s "DELETE FROM $SCHEMA.GeneCoexpression WHERE external_database_release_id = $EXTDB;\n";
  print $s "\\copy $SCHEMA.GeneCoexpression ($cols) FROM '$tmpFile' WITH (FORMAT CSV, DELIMITER E'\\t', QUOTE '`', ENCODING 'UTF8')\n";
  print $s "COMMIT;\n";
  close $s;
  my $logFile = "$dir/psql.log";
  my $rc = system("$PSQL -v ON_ERROR_STOP=1 -f '$sqlFile' >'$logFile' 2>&1");
  if ($rc != 0 && -e $logFile) {
    open(my $lh, '<', $logFile) or return $rc;
    diag("psql: $_") while <$lh>;
    close $lh;
  }
  return $rc;
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
