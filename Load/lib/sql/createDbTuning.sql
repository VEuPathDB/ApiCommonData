CREATE INDEX dots.NaFeat_SubclassParent_ix
ON dots.NaFeatureImp (subclass_view, parent_id, na_feature_id);

-------------------------------------------------------------------------------

CREATE MATERIALIZED VIEW GeneAlias AS
SELECT DISTINCT alias, gene FROM
(SELECT ng.name AS alias, gf.source_id AS gene
 FROM dots.GeneFeature gf, dots.NaFeatureNaGene nfng, dots.NaGene ng
 WHERE gf.na_feature_id = nfng.na_feature_id
   AND ng.na_gene_id = nfng.na_gene_id
 UNION
 SELECT LOWER(ng.name) AS alias, gf.source_id AS gene
 FROM dots.GeneFeature gf, dots.NaFeatureNaGene nfng, dots.NaGene ng
 WHERE gf.na_feature_id = nfng.na_feature_id
   AND ng.na_gene_id = nfng.na_gene_id
 UNION
 SELECT source_id AS alias, source_id AS gene
 FROM dots.GeneFeature
 UNION
 SELECT lower(source_id) AS alias, source_id AS gene
 FROM dots.GeneFeature);

GRANT SELECT ON GeneAlias TO gus_r;

CREATE INDEX GeneAlias_gene_idx ON GeneAlias (gene);
CREATE INDEX GeneAlias_alias_idx ON GeneAlias (alias);

-------------------------------------------------------------------------------

CREATE MATERIALIZED VIEW SequenceAlias AS
SELECT ens.source_id, LOWER(ens.source_id) AS lowercase_source_id
FROM dots.ExternalNaSequence ens;

CREATE INDEX SequenceAlias_idx ON SequenceAlias.lowercase_source_id;

GRANT SELECT ON SequenceAlias TO gus_r;

exit
