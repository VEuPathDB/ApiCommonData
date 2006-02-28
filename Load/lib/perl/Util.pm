package ApiCommonData::Load::Util;

use strict;

# return null if not found:  be sure to check handle that condition!!
sub getGeneFeatureId {
  my ($plugin, $sourceId) = @_;

  if (!$plugin->{sourceIdFeatureIdMap}) {

    $plugin->{sourceIdFeatureIdMap} = {};

    my $sql = "
SELECT source_id, na_feature_id
FROM Dots.GeneFeature
UNION
SELECT g.name, gf.na_feature_id
FROM Dots.GeneFeature gf, Dots.NAFeatureNAGene nfng, Dots.NAGene g
WHERE nfng.na_feature_id = gf.na_feature_id
AND nfng.na_gene_id = g.na_gene_id
";
    my $stmt = $plugin->prepareAndExecute($sql);
    while ( my($sourceId, $na_feature_id) = $stmt->fetchrow_array()) {
      $plugin->{sourceIdFeatureIdMap}->{$sourceId} = $na_feature_id;
    }
  }

  return $plugin->{sourceIdFeatureIdMap}->{$sourceId};
}

1;
