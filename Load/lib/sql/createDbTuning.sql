
-- indexes to tune GUS

CREATE INDEX dots.NaFeat_SubclassParent_ix
ON dots.NaFeatureImp (subclass_view, parent_id, na_feature_id);

CREATE INDEX dots.aafeat_subclassparent_ix
ON dots.AaFeatureImp (subclass_view, parent_id, aa_feature_id);

CREATE INDEX dots.aaseq_subclassdbrel_ix
ON dots.AaSequenceImp (external_database_release_id, subclass_view,
                      aa_sequence_id);

CREATE INDEX dots.NaFeat_alleles_ix ON dots.NaFeatureImp(subclass_view, number4, number5, na_sequence_id, na_feature_id); 

-------------------------------------------------------------------------------

-- materialized views


-- first, needed privileges

GRANT CREATE TABLE TO apidb;
GRANT CREATE MATERIALIZED VIEW TO apidb;

GRANT REFERENCES ON dots.ExternalNaSequence TO apidb;
GRANT REFERENCES ON dots.GeneFeature TO apidb;
GRANT REFERENCES ON dots.Transcript TO apidb;
GRANT REFERENCES ON dots.TranslatedAaFeature TO apidb;
GRANT REFERENCES ON dots.GoAssociation TO apidb;
GRANT REFERENCES ON dots.GoAssociationInstance TO apidb;
GRANT REFERENCES ON dots.GoAssociationInstanceLoe TO apidb;
GRANT REFERENCES ON dots.GoAssocInstEvidCode TO apidb;
GRANT REFERENCES ON core.TableInfo TO apidb;
GRANT REFERENCES ON dots.NaFeatureNaGene TO apidb;
GRANT REFERENCES ON dots.NaGene TO apidb;
GRANT REFERENCES ON dots.SeqVariation TO apidb;
GRANT REFERENCES ON dots.SnpFeature TO apidb;
GRANT REFERENCES ON sres.ExternalDatabase TO apidb;
GRANT REFERENCES ON sres.ExternalDatabaseRelease TO apidb;
GRANT REFERENCES ON sres.GoTerm TO apidb;
GRANT REFERENCES ON sres.GoEvidenceCode TO apidb;
GRANT REFERENCES ON sres.GoRelationship TO apidb;

GRANT SELECT ON dots.ExternalNaSequence TO apidb WITH GRANT OPTION;
GRANT SELECT ON dots.GeneFeature TO apidb WITH GRANT OPTION;
GRANT SELECT ON dots.Transcript TO apidb WITH GRANT OPTION;
GRANT SELECT ON dots.TranslatedAaFeature TO apidb WITH GRANT OPTION;
GRANT SELECT ON dots.GoAssociation TO apidb WITH GRANT OPTION;
GRANT SELECT ON dots.GoAssociationInstance TO apidb WITH GRANT OPTION;
GRANT SELECT ON dots.GoAssociationInstanceLoe TO apidb WITH GRANT OPTION;
GRANT SELECT ON dots.GoAssocInstEvidCode TO apidb WITH GRANT OPTION;
GRANT SELECT ON dots.SeqVariation TO apidb WITH GRANT OPTION;
GRANT SELECT ON dots.SnpFeature TO apidb WITH GRANT OPTION;
GRANT SELECT ON sres.ExternalDatabaseRelease TO apidb WITH GRANT OPTION;
GRANT SELECT ON sres.ExternalDatabase TO apidb WITH GRANT OPTION;
GRANT SELECT ON sres.GoTerm TO apidb WITH GRANT OPTION;
GRANT SELECT ON sres.GoEvidenceCode TO apidb WITH GRANT OPTION;
GRANT SELECT ON sres.GoRelationship TO apidb WITH GRANT OPTION;
GRANT SELECT ON core.TableInfo TO apidb WITH GRANT OPTION;
GRANT SELECT ON dots.NaFeatureNaGene TO apidb WITH GRANT OPTION;
GRANT SELECT ON dots.NaGene TO apidb WITH GRANT OPTION;

-------------------------------------------------------------------------------

CREATE MATERIALIZED VIEW apidb.GeneAlias AS
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

GRANT SELECT ON apidb.GeneAlias TO gus_r;

CREATE INDEX apidb.GeneAlias_gene_idx ON apidb.GeneAlias (gene);
CREATE INDEX apidb.GeneAlias_alias_idx ON apidb.GeneAlias (alias);

-------------------------------------------------------------------------------

CREATE MATERIALIZED VIEW apidb.SequenceAlias AS
SELECT ens.source_id, LOWER(ens.source_id) AS lowercase_source_id
FROM dots.ExternalNaSequence ens;

CREATE INDEX apidb.SequenceAlias_idx ON apidb.SequenceAlias(lowercase_source_id);

GRANT SELECT ON apidb.SequenceAlias TO gus_r;

-------------------------------------------------------------------------------

CREATE MATERIALIZED VIEW apidb.GoTermSummary AS
SELECT gf.source_id, 
       decode(ga.is_not, 0, '', 1, 'not', ga.is_not) as is_not,
                 gt.go_id, o.ontology, gt.name AS go_term_name,
                  gail.name AS source, gec.name as evidence_code
FROM dots.GeneFeature gf, dots.Transcript t,
     dots.TranslatedAaFeature taf, dots.GoAssociation ga,
     sres.GoTerm gt, dots.GoAssociationInstance gai,
     dots.GoAssociationInstanceLoe gail,
     dots.GoAssocInstEvidCode gaiec, sres.GoEvidenceCode gec,
     (SELECT gr.child_term_id AS go_term_id,
             DECODE(gp.name, 'biological_process', 'Biological Process',
                             'molecular_function', 'Molecular Function',
                             'cellular_component', 'Cellular Component',
                              gp.name)
             AS ontology
      FROM sres.GoRelationship gr, sres.GoTerm gp
      WHERE gr.parent_term_id = gp.go_term_id
        AND gp.go_id in ('GO:0008150','GO:0003674','GO:0005575')) o
WHERE gf.na_feature_id = t.parent_id
  AND t.na_feature_id = taf.na_feature_id
  AND taf.aa_sequence_id = ga.row_id
  AND ga.table_id = (SELECT table_id
                     FROM core.TableInfo
                     WHERE name = 'TranslatedAASequence')
  AND ga.go_term_id = gt.go_term_id
  AND ga.go_association_id = gai.go_association_id
  AND gai.go_assoc_inst_loe_id = gail.go_assoc_inst_loe_id
  AND gai.go_association_instance_id
      = gaiec.go_association_instance_id
  AND gaiec.go_evidence_code_id = gec.go_evidence_code_id
  AND gt.go_term_id = o.go_term_id(+)
ORDER BY o.ontology, gt.go_id;

CREATE INDEX apidb.GoTermSum_sourceId_idx ON apidb.GoTermSummary (source_id);

GRANT SELECT ON apidb.GoTermSummary TO gus_r;

-------------------------------------------------------------------------------

-- GUS table shortcomings

ALTER TABLE core.AlgorithmParam MODIFY (string_value VARCHAR2(2000));

ALTER TABLE sres.DbRef MODIFY (secondary_identifier varchar2(100));

exit
