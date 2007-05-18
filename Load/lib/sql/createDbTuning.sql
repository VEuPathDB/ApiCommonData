
-- indexes to tune GUS

CREATE INDEX dots.NaFeat_SubclassParent_ix
ON dots.NaFeatureImp (subclass_view, parent_id, na_feature_id);

CREATE INDEX dots.aafeat_subclassparent_ix
ON dots.AaFeatureImp (subclass_view, parent_id, aa_feature_id);

CREATE INDEX aafeature_subclasssource_ix
ON dots.AaFeatureImp (subclass_view, source_id, aa_feature_id); 

CREATE INDEX dots.aaseq_subclassdbrel_ix
ON dots.AaSequenceImp (external_database_release_id, subclass_view,
                      aa_sequence_id);

CREATE INDEX dots.NaFeat_alleles_ix
ON dots.NaFeatureImp (subclass_view, number4, number5, na_sequence_id,
                     na_feature_id);

CREATE INDEX dots.AaSequenceImp_string2_ix
ON dots.AaSequenceImp (string2, aa_sequence_id);

CREATE INDEX dots.NaFeat_SubclassSource_ix
ON dots.NaFeatureImp (subclass_view, source_id);

CREATE INDEX dots.loc_feat_ix
       ON dots.NaLocation(na_feature_id, start_min, end_max, is_reversed);

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
GRANT REFERENCES ON dots.ExternalAaSequence TO apidb;
GRANT REFERENCES ON dots.Similarity TO apidb;
GRANT REFERENCES ON dots.TranslatedAaSequence TO apidb;
GRANT REFERENCES ON dots.DbRefNaFeature TO apidb;
GRANT REFERENCES ON dots.DbRefNaSequence TO apidb;
GRANT REFERENCES ON dots.SplicedNaSequence TO apidb;
GRANT REFERENCES ON sres.ExternalDatabase TO apidb;
GRANT REFERENCES ON sres.ExternalDatabaseRelease TO apidb;
GRANT REFERENCES ON sres.GoTerm TO apidb;
GRANT REFERENCES ON sres.GoEvidenceCode TO apidb;
GRANT REFERENCES ON sres.GoRelationship TO apidb;
GRANT REFERENCES ON sres.TaxonName TO apidb;
GRANT REFERENCES ON sres.DbRef TO apidb;

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
GRANT SELECT ON dots.ExternalAaSequence TO apidb WITH GRANT OPTION;
GRANT SELECT ON dots.Similarity TO apidb WITH GRANT OPTION;
GRANT SELECT ON dots.TranslatedAaSequence TO apidb WITH GRANT OPTION;
GRANT SELECT ON sres.ExternalDatabaseRelease TO apidb WITH GRANT OPTION;
GRANT SELECT ON sres.ExternalDatabase TO apidb WITH GRANT OPTION;
GRANT SELECT ON sres.GoTerm TO apidb WITH GRANT OPTION;
GRANT SELECT ON sres.GoEvidenceCode TO apidb WITH GRANT OPTION;
GRANT SELECT ON sres.GoRelationship TO apidb WITH GRANT OPTION;
GRANT SELECT ON sres.TaxonName TO apidb WITH GRANT OPTION;
GRANT SELECT ON sres.DbRef TO apidb WITH GRANT OPTION;
GRANT SELECT ON core.TableInfo TO apidb WITH GRANT OPTION;
GRANT SELECT ON dots.NaFeatureNaGene TO apidb WITH GRANT OPTION;
GRANT SELECT ON dots.NaGene TO apidb WITH GRANT OPTION;
GRANT SELECT ON dots.DbRefNaFeature TO apidb WITH GRANT OPTION;
GRANT SELECT ON dots.DbRefNaSequence TO apidb WITH GRANT OPTION;
GRANT SELECT ON dots.SplicedNaSequence TO apidb WITH GRANT OPTION;

-------------------------------------------------------------------------------

prompt DROP/CREATE MATERIALIZED VIEW apidb.GeneAlias;

DROP MATERIALIZED VIEW apidb.GeneAlias;
CREATE MATERIALIZED VIEW apidb.GeneAlias AS
SELECT DISTINCT pairs.alias, pairs.gene FROM
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
 FROM dots.GeneFeature) pairs,
      dots.GeneFeature gf, sres.ExternalDatabaseRelease edr,
      sres.ExternalDatabase ed
WHERE pairs.gene = gf.source_id
  AND gf.external_database_release_id = edr.external_database_release_id
  AND edr.external_database_id = ed.external_database_id
  AND ed.name NOT IN ('GLEAN predictions', 'GlimmerHMM predictions',
                      'TigrScan', /*'tRNAscan-SE',*/ 'TwinScan predictions',
                      'TwinScanEt predictions');

GRANT SELECT ON apidb.GeneAlias TO gus_r;

CREATE INDEX apidb.GeneAlias_gene_idx ON apidb.GeneAlias (gene);
CREATE INDEX apidb.GeneAlias_alias_idx ON apidb.GeneAlias (alias);

-------------------------------------------------------------------------------

prompt DROP/CREATE MATERIALIZED VIEW apidb.SequenceAlias;

DROP MATERIALIZED VIEW apidb.SequenceAlias;
CREATE MATERIALIZED VIEW apidb.SequenceAlias AS
SELECT ens.source_id, LOWER(ens.source_id) AS lowercase_source_id
FROM dots.ExternalNaSequence ens;

CREATE INDEX apidb.SequenceAlias_idx ON apidb.SequenceAlias(lowercase_source_id);

GRANT SELECT ON apidb.SequenceAlias TO gus_r;

-------------------------------------------------------------------------------

prompt DROP/CREATE MATERIALIZED VIEW apidb.GoTermSummary;

DROP MATERIALIZED VIEW apidb.GoTermSummary;
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

prompt DROP/CREATE MATERIALIZED VIEW apidb.PdbSimilarity;

DROP MATERIALIZED VIEW apidb.PdbSimilarity;
CREATE MATERIALIZED VIEW apidb.PdbSimilarity AS
SELECT gf.source_id, eas.source_id AS pdb_chain, eas.description AS pdb_title,
       substr(eas.source_id, 1,
              instr(eas.source_id, '_', -1) - 1)
         AS pdb_id,
       s.pvalue_mant, s.pvalue_exp, tn.name AS taxon,
       ROUND( (s.number_identical / s.total_match_length) * 100)
         AS percent_identity,
       ROUND( (s.total_match_length / tas.length) * 100)
         AS percent_plasmo_coverage,
       s.score
FROM dots.TranslatedAaFeature taf,
     dots.TranslatedAaSequence tas, core.TableInfo tas_ti,
     dots.Similarity s, core.TableInfo eas_ti,
     dots.ExternalAaSequence eas,
     sres.ExternalDatabaseRelease edr, sres.ExternalDatabase ed,
     sres.TaxonName tn, dots.Transcript t, dots.GeneFeature gf
WHERE taf.aa_sequence_id = tas.aa_sequence_id
  AND tas_ti.name = 'TranslatedAASequence'
  AND tas_ti.table_id = s.query_table_id
  AND s.query_id = tas.aa_sequence_id
  AND eas_ti.name = 'ExternalAASequence'
  AND eas_ti.table_id = s.subject_table_id
  AND s.subject_id = eas.aa_sequence_id
  AND tn.name_class = 'scientific name'
  AND eas.external_database_release_id
      = edr.external_database_release_id
  AND edr.external_database_id = ed.external_database_id
  AND ed.name = 'PDB protein sequences'
  AND eas.taxon_id = tn.taxon_id
  AND t.na_feature_id = taf.na_feature_id
  AND gf.na_feature_id = t.parent_id
ORDER BY taf.source_id, eas.source_id;

CREATE INDEX apidb.PdbSim_sourceId_ix
ON apidb.PdbSimilarity (source_id, score DESC);

GRANT SELECT on apidb.PdbSimilarity TO gus_r;

-------------------------------------------------------------------------------

prompt DROP/CREATE MATERIALIZED VIEW apidb.GeneId;

DROP MATERIALIZED VIEW apidb.GeneId;
CREATE MATERIALIZED VIEW apidb.GeneId AS
SELECT LOWER(dr.primary_identifier) AS id, gf.source_id AS gene
FROM dots.GeneFeature gf, dots.DbRefNaFeature drnf,
     sres.DbRef dr, sres.ExternalDatabaseRelease edr,
     sres.ExternalDatabase ed
WHERE dr.primary_identifier IS NOT NULL
  AND gf.na_feature_id = drnf.na_feature_id
  AND drnf.db_ref_id = dr.db_ref_id
  AND dr.external_database_release_id
        = edr.external_database_release_id
  AND edr.external_database_id = ed.external_database_id
  AND ed.name IN ('NRDB_gb_dbXRefBySeqIdentity',
                  'NRDB_pdb_dbXRefBySeqIdentity',
                  'NRDB_ref_dbXRefBySeqIdentity',
                  'NRDB_sp_dbXRefBySeqIdentity',
                  'Predicted protein structures',
                  'GenBank')
UNION
SELECT LOWER(dr.secondary_identifier) AS id, gf.source_id AS gene
FROM dots.GeneFeature gf, dots.DbRefNaFeature drnf,
     sres.DbRef dr, sres.ExternalDatabaseRelease edr,
     sres.ExternalDatabase ed
WHERE dr.secondary_identifier IS NOT NULL
  AND gf.na_feature_id = drnf.na_feature_id
  AND drnf.db_ref_id = dr.db_ref_id
  AND dr.external_database_release_id
        = edr.external_database_release_id
  AND edr.external_database_id = ed.external_database_id
  AND ed.name IN ('NRDB_gb_dbXRefBySeqIdentity',
                  'NRDB_pdb_dbXRefBySeqIdentity',
                  'NRDB_ref_dbXRefBySeqIdentity',
                  'NRDB_sp_dbXRefBySeqIdentity',
                  'Predicted protein structures',
                  'GenBank')
UNION
SELECT lower(dr.primary_identifier) AS id, sns.source_id AS gene
FROM dots.SplicedNaSequence sns, dots.dbrefNaSequence drns,
     sres.DbRef dr, sres.ExternalDatabaseRelease edr,
      sres.ExternalDatabase ed
WHERE sns.na_sequence_id = drns.na_sequence_id
  AND drns.db_ref_id = dr.db_ref_id
  AND dr.external_database_release_id = edr.external_database_release_id
  AND edr.external_database_id = ed.external_database_id 
  AND ed.name = 'GenBank'
UNION
SELECT LOWER(alias) AS id, gene FROM apidb.GeneAlias;

GRANT SELECT ON apidb.GeneId TO gus_r;

CREATE INDEX apidb.GeneId_gene_idx ON apidb.GeneId (gene);
CREATE INDEX apidb.GeneId_id_idx ON apidb.GeneId (id);

-------------------------------------------------------------------------------

prompt DROP/CREATE MATERIALIZED VIEW apidb.EpitopeSummary;

DROP MATERIALIZED VIEW apidb.EpitopeSummary;

CREATE MATERIALIZED VIEW apidb.EpitopeSummary AS
SELECT gf.source_id, dr.primary_identifier AS iedb_id,
       al.start_min||'-'||al.end_max AS location,
       mas.sequence, tn.name,
       DECODE(ef.type, 'Not Full Set Not on Blast Hit', 'Low',
                       'Not Full Set On Blast Hit', 'Medium',
                       'Full Set Not on Blast Hit', 'Medium',
                       'Full Set On Blast Hit', 'High',
                       'unknown epitope type') AS confidence
FROM dots.GeneFeature gf, dots.Transcript t,
     dots.TranslatedAaFeature taf, dots.MotifAaSequence mas,
     dots.TranslatedAaSequence tas, dots.EpitopeFeature ef,
     dots.AaLocation al, dots.AaSequenceDbRef asdr,
     sres.DbRef dr, sres.ExternalDatabaseRelease edr,
     sres.ExternalDatabase ed, Sres.TaxonName tn
WHERE t.parent_id = gf.na_feature_id
  AND taf.na_feature_id = t.na_feature_id
  AND taf.aa_sequence_id = tas.aa_sequence_id
  AND tas.aa_sequence_id = ef.aa_sequence_id
  AND ef.aa_feature_id = al.aa_feature_id
  AND ef.motif_aa_sequence_id = mas.aa_sequence_id
  AND mas.aa_sequence_id = asdr.aa_sequence_id
  AND asdr.db_ref_id = dr.db_ref_id
  AND mas.taxon_id = tn.taxon_id
  AND tn.name_class = 'scientific name'
  AND ef.external_database_release_id
      = edr.external_database_release_id
  AND edr.external_database_id = ed.external_database_id
  AND ed.name = 'Links to IEDB epitopes';

GRANT SELECT ON apidb.EpitopeSummary TO gus_r;

CREATE INDEX apidb.Epi_srcId_ix ON apidb.EpitopeSummary (source_id);

-------------------------------------------------------------------------------

prompt DROP/CREATE MATERIALIZED VIEW apidb.EstAlignmentGeneSummary;

DROP MATERIALIZED VIEW apidb.EstAlignmentGeneSummary;

CREATE MATERIALIZED VIEW apidb.EstAlignmentGeneSummary AS
SELECT ba.blat_alignment_id, ba.query_na_sequence_id, e.accession,
         e.library_id, ba.query_taxon_id, ba.target_na_sequence_id,
         ba.target_taxon_id, ba.percent_identity, ba.is_consistent,
         ba.is_best_alignment, ba.is_reversed, ba.target_start, ba.target_end,
         sequence.source_id AS target_sequence_source_id,
         least(ba.target_end, l.end_max)
         - greatest(ba.target_start, l.start_min) + 1
           AS est_gene_overlap_length,
         ba.query_bases_aligned / (aseq.sequence_end - aseq.sequence_start + 1)
         * 100 AS percent_est_bases_aligned,
         gf.source_id AS gene
  FROM dots.blatalignment ba, dots.est e, dots.AssemblySequence aseq,
       dots.genefeature gf, dots.nalocation l, sres.ExternalDatabaseRelease edr,
       sres.ExternalDatabase ed,
       (select source_id, na_sequence_id from dots.ExternalNaSequence
        union
        select source_id, na_sequence_id from dots.VirtualSequence) sequence
  WHERE e.na_sequence_id = ba.query_na_sequence_id
    AND aseq.na_sequence_id = ba.query_na_sequence_id
    AND gf.na_sequence_id = ba.target_na_sequence_id
    AND gf.na_feature_id = l.na_feature_id
    AND least(ba.target_end, l.end_max) - greatest(ba.target_start, l.start_min) >= 0
    AND ba.query_external_db_release_id = edr.external_database_release_id
    AND edr.external_database_id = ed.external_database_id
    AND ed.name = 'dbEST'
    AND ba.target_na_sequence_id = sequence.na_sequence_id
UNION
  SELECT ba.blat_alignment_id, ba.query_na_sequence_id, e.accession,
         e.library_id, ba.query_taxon_id, ba.target_na_sequence_id,
         ba.target_taxon_id, ba.percent_identity, ba.is_consistent,
         ba.is_best_alignment, ba.is_reversed, ba.target_start, ba.target_end,
         sequence.source_id AS target_sequence_source_id,
         NULL AS est_gene_overlap_length,
         ba.query_bases_aligned / (aseq.sequence_end - aseq.sequence_start + 1)
         * 100 AS percent_est_bases_aligned,
         NULL AS gene
  FROM dots.blatalignment ba, dots.est e, dots.AssemblySequence aseq,
       (select source_id, na_sequence_id from dots.ExternalNaSequence
        union
        select source_id, na_sequence_id from dots.VirtualSequence) sequence
  WHERE e.na_sequence_id = ba.query_na_sequence_id
    AND aseq.na_sequence_id = ba.query_na_sequence_id
    AND ba.target_na_sequence_id = sequence.na_sequence_id
    AND ba.blat_alignment_id IN
  ( -- set of blat_alignment_ids not in in first leg of UNION
    -- (because they overlap no genes)
    SELECT ba.blat_alignment_id
    FROM dots.BlatAlignment ba, sres.ExternalDatabaseRelease edr,
         sres.ExternalDatabase ed
    WHERE ba.query_external_db_release_id = edr.external_database_release_id
      AND edr.external_database_id = ed.external_database_id
      AND ed.name = 'dbEST'
  MINUS
    SELECT ba.blat_alignment_id
    FROM dots.blatalignment ba, dots.est e, dots.AssemblySequence aseq,
         dots.genefeature gf, dots.nalocation l
    WHERE e.na_sequence_id = ba.query_na_sequence_id
      AND aseq.na_sequence_id = ba.query_na_sequence_id
      AND gf.na_sequence_id = ba.target_na_sequence_id
      AND gf.na_feature_id = l.na_feature_id
      AND least(ba.target_end, l.end_max)
          - greatest(ba.target_start, l.start_min) >= 0
  );

GRANT SELECT ON apidb.EstAlignmentGeneSummary TO gus_r;

CREATE INDEX apidb.EstSumm_libOverlap_ix
             ON apidb.EstAlignmentGeneSummary
                (library_id, percent_identity, is_consistent,
                 est_gene_overlap_length, percent_est_bases_aligned);

CREATE INDEX apidb.EstSumm_estSite_ix
             ON apidb.EstAlignmentGeneSummary
                (target_sequence_source_id, target_start, target_end,
                 library_id);

-------------------------------------------------------------------------------

-- GUS table shortcomings

ALTER TABLE core.AlgorithmParam MODIFY (string_value VARCHAR2(2000));

ALTER TABLE sres.DbRef MODIFY (secondary_identifier varchar2(100));

exit
