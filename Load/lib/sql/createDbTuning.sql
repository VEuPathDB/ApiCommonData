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

GRANT SELECT on GeneAlias TO gus_r;

CREATE INDEX GeneAlias_gene_idx ON GeneAlias (gene);
CREATE INDEX GeneAlias_alias_idx ON GeneAlias (alias);

exit
