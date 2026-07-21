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
