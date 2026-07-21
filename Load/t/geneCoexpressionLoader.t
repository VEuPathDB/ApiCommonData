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

done_testing;
