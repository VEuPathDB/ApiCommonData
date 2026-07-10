use strict;
use warnings;
use lib "$ENV{GUS_HOME}/lib/perl";
use Test::More;
use File::Temp qw/tempdir/;
use ApiCommonData::Load::VariationLoader qw/
  variationFeatureColumns transcriptProductColumns variationEffectColumns
  transformVariationFeature transformTranscriptProduct transformVariationEffect
/;

# Off by default: this test loads into a live Postgres via psql. Enable it by
# setting VARIATION_DB_TEST=1. Connection and sample-data location are taken
# from the environment so it is not pinned to any one developer's box.
plan skip_all => "set VARIATION_DB_TEST=1 to run the live-DB integration test"
  unless $ENV{VARIATION_DB_TEST};

my $INPUT  = $ENV{VARIATION_TEST_INPUT} || '/home/jbrestel/dnaseq_test/merge/output';
my $HOST   = $ENV{VARIATION_DB_HOST}    || 'localhost';
my $PORT   = $ENV{VARIATION_DB_PORT}    || '5432';
my $DB     = $ENV{VARIATION_DB_NAME}    || 'unidb_shu_a';
my $SCHEMA = $ENV{VARIATION_DB_SCHEMA}  || 'jbrestel';
my $PSQL   = "psql -h $HOST -p $PORT -d $DB";
plan skip_all => "sample data $INPUT not present" unless -d $INPUT;

# Build the transcript map from <schema>.StubTranscript via psql.
my %map;
open(my $m, "-|", "$PSQL -tAF'\t' -c "
  . "'SELECT source_id, na_feature_id FROM $SCHEMA.stubtranscript'") or die $!;
while (<$m>) { chomp; my ($s,$n) = split /\t/; $map{$s} = $n if $s; }
close $m;
is(scalar keys %map, 78, 'stub transcript map has 78 entries');

my $dir = tempdir(CLEANUP => 1);
my %n;
for ([qw/variationFeature.dat vf/], [qw/transcript_product.dat tp/], [qw/snpeff.dat ve/]) {
  my ($file, $tag) = @$_;
  open(my $in, '<', "$INPUT/$file") or die $!;
  open(my $out, '>', "$dir/$tag.tmp") or die $!;
  $n{$tag} =
      $tag eq 'vf' ? transformVariationFeature($in, $out, 1)
    : $tag eq 'tp' ? transformTranscriptProduct($in, $out, \%map)
    :                transformVariationEffect($in, $out, \%map);
  close $in; close $out;
}
is($n{vf}, 1504, 'vf rows'); is($n{tp}, 781, 'tp rows'); is($n{ve}, 1978, 've rows');

# Assemble and run the single-transaction load into <schema>.
my $vfCols = join(", ", @{variationFeatureColumns()});
my $tpCols = join(", ", @{transcriptProductColumns()});
my $veCols = join(", ", @{variationEffectColumns()});
my $sqlFile = "$dir/load.sql";
open(my $s, '>', $sqlFile) or die $!;
print $s "BEGIN;\n";
print $s "DELETE FROM $SCHEMA.VariationFeature WHERE external_database_release_id = 1;\n";
print $s "\\copy $SCHEMA.VariationFeature ($vfCols) FROM '$dir/vf.tmp' WITH (FORMAT CSV, DELIMITER E'\\t', QUOTE '`', ENCODING 'UTF8')\n";
print $s "\\copy $SCHEMA.VariationTranscriptProduct ($tpCols) FROM '$dir/tp.tmp' WITH (FORMAT CSV, DELIMITER E'\\t', QUOTE '`', ENCODING 'UTF8')\n";
print $s "\\copy $SCHEMA.VariationEffect ($veCols) FROM '$dir/ve.tmp' WITH (FORMAT CSV, DELIMITER E'\\t', QUOTE '`', ENCODING 'UTF8')\n";
print $s "COMMIT;\n";
close $s;

my $rc = system("$PSQL -v ON_ERROR_STOP=1 -f '$sqlFile' >/dev/null 2>&1");
is($rc, 0, 'single-transaction load succeeded');

sub count1 {
  my ($tbl) = @_;
  my $c = `$PSQL -tAc "SELECT count(*) FROM $SCHEMA.$tbl"`;
  chomp $c; return $c;
}
is(count1('VariationFeature'), 1504, 'VariationFeature loaded');
is(count1('VariationTranscriptProduct'), 781, 'VariationTranscriptProduct loaded');
is(count1('VariationEffect'), 1978, 'VariationEffect loaded');

# Intergenic rows -> NULL na_feature_id: 1978 - 1181 = 797 non-null.
my $nn = `$PSQL -tAc "SELECT count(na_feature_id) FROM $SCHEMA.VariationEffect"`;
chomp $nn;
is($nn, 797, 'VariationEffect na_feature_id non-null count (empty -> NULL)');

# Cascade delete clears all three (the undo path).
system("$PSQL -c 'DELETE FROM $SCHEMA.VariationFeature WHERE external_database_release_id = 1' >/dev/null 2>&1");
is(count1('VariationTranscriptProduct'), 0, 'children cascade-deleted');

done_testing;
