grant select on DoTS.GeneFeature to PlasmoDB;
grant select on DoTS.NAGene to PlasmoDB;
grant select on DoTS.NAFeatureNAGene to PlasmoDB;

CREATE VIEW plasmodb.GeneNameMapping AS
SELECT g.name AS alias, gf.source_id
FROM dots.NaGene g, dots.naFeatureNaGene nfg, dots.GeneFeature gf
WHERE g.na_gene_id = nfg.na_gene_id
  AND nfg.na_feature_id = gf.na_feature_id
UNION
SELECT source_id AS alias, source_id
FROM dots.GeneFeature;

GRANT SELECT ON plasmodb.GeneNameMapping TO gus_r;

exit
