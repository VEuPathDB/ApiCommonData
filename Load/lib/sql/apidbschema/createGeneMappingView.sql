GRANT SELECT ON dots.GeneFeature TO apidb WITH GRANT OPTION;
GRANT SELECT ON dots.NaGene TO apidb WITH GRANT OPTION;
GRANT SELECT ON dots.NaFeatureNaGene TO apidb WITH GRANT OPTION;

CREATE VIEW apidb.GeneNameMapping AS
SELECT g.name AS alias, gf.source_id
FROM dots.NaGene g, dots.naFeatureNaGene nfg, dots.GeneFeature gf
WHERE g.na_gene_id = nfg.na_gene_id
  AND nfg.na_feature_id = gf.na_feature_id
UNION
SELECT source_id AS alias, source_id
FROM dots.GeneFeature;

GRANT SELECT ON apidb.GeneNameMapping TO gus_r;

exit
