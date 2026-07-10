use strict;
use warnings;
use lib "$ENV{GUS_HOME}/lib/perl";
use Test::More;
use File::Temp qw/tempdir/;
use ApiCommonData::Load::VariationLoader qw/
  variationFeatureColumns transcriptProductColumns variationEffectColumns
  transformVariationFeature transformTranscriptProduct transformVariationEffect
/;

my $INPUT = '/home/jbrestel/dnaseq_test/merge/output';
my $DB    = 'unidb_shu_a';
plan skip_all => "sample data $INPUT not present" unless -d $INPUT;

# Build the transcript map from jbrestel.StubTranscript via psql.
my %map;
open(my $m, "-|", "psql -h localhost -p 5432 -d $DB -tAF'\t' -c "
  . "'SELECT source_id, na_feature_id FROM jbrestel.stubtranscript'") or die $!;
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

# Assemble and run the single-transaction load into jbrestel.
my $vfCols = join(", ", @{variationFeatureColumns()});
my $tpCols = join(", ", @{transcriptProductColumns()});
my $veCols = join(", ", @{variationEffectColumns()});
my $sqlFile = "$dir/load.sql";
open(my $s, '>', $sqlFile) or die $!;
print $s "BEGIN;\n";
print $s "DELETE FROM jbrestel.VariationFeature WHERE external_database_release_id = 1;\n";
print $s "\\copy jbrestel.VariationFeature ($vfCols) FROM '$dir/vf.tmp' WITH (FORMAT CSV, DELIMITER E'\\t', QUOTE '`', ENCODING 'UTF8')\n";
print $s "\\copy jbrestel.VariationTranscriptProduct ($tpCols) FROM '$dir/tp.tmp' WITH (FORMAT CSV, DELIMITER E'\\t', QUOTE '`', ENCODING 'UTF8')\n";
print $s "\\copy jbrestel.VariationEffect ($veCols) FROM '$dir/ve.tmp' WITH (FORMAT CSV, DELIMITER E'\\t', QUOTE '`', ENCODING 'UTF8')\n";
print $s "COMMIT;\n";
close $s;

my $rc = system("psql -h localhost -p 5432 -d $DB -v ON_ERROR_STOP=1 -f '$sqlFile' >/dev/null 2>&1");
is($rc, 0, 'single-transaction load succeeded');

sub count1 {
  my ($tbl) = @_;
  my $c = `psql -h localhost -p 5432 -d $DB -tAc "SELECT count(*) FROM jbrestel.$tbl"`;
  chomp $c; return $c;
}
is(count1('VariationFeature'), 1504, 'VariationFeature loaded');
is(count1('VariationTranscriptProduct'), 781, 'VariationTranscriptProduct loaded');
is(count1('VariationEffect'), 1978, 'VariationEffect loaded');

# Intergenic rows -> NULL na_feature_id: 1978 - 1181 = 797 non-null.
my $nn = `psql -h localhost -p 5432 -d $DB -tAc "SELECT count(na_feature_id) FROM jbrestel.VariationEffect"`;
chomp $nn;
is($nn, 797, 'VariationEffect na_feature_id non-null count (empty -> NULL)');

# Cascade delete clears all three (the undo path).
system("psql -h localhost -p 5432 -d $DB -c 'DELETE FROM jbrestel.VariationFeature WHERE external_database_release_id = 1' >/dev/null 2>&1");
is(count1('VariationTranscriptProduct'), 0, 'children cascade-deleted');

done_testing;
