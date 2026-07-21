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
