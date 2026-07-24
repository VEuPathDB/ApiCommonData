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

1;
