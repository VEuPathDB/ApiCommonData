package ApiCommonData::Load::Util;

use strict;

use GUS::Model::DoTS::TranslatedAAFeature;
use GUS::Model::DoTS::TranslatedAASequence;

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


sub getAASeqIdFromFeatId {
  my ($featId) = shift;

  my $gusTAAF = GUS::Model::DoTS::TranslatedAAFeature->new( { 'na_feature_id' => $featId, } );

  $gusTAAF->retrieveFromDB()
    or die "no translated aa sequence: $featId";

  my $gusAASeq = $gusTAAF->getAaSequenceId();

  return $gusAASeq;
}


# get an aa seq id from a source_id or source_id alias.
sub getAASeqIdFromGeneId {
  my ($plugin, $geneId) = @_;

  my $featId = getGeneFeatureId($plugin, $geneId);
  return getAASeqIdFromFeatId($featId);
}


sub getAASeqIdFromCaselessSourceId {
  my ($plugin, $sourceId) = @_;

    $sourceId = uc($sourceId);

    my $sql = "SELECT aa_sequence_id
               FROM DoTS.TranslatedAASequence
               Where upper(source_id) = \'$sourceId\'";

    my $recordSet = $plugin->prepareAndExecute($sql);
    my($aaSeqId) = $recordSet->fetchrow_array(); 
                                                                                                                             
return $aaSeqId;
}



1;


