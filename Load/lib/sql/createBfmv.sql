set time on timing on
---------------------------
-- set permissions
---------------------------

GRANT CREATE TABLE TO apidb;
GRANT CREATE MATERIALIZED VIEW TO apidb;

GRANT REFERENCES ON dots.ExternalNaSequence TO apidb;
GRANT SELECT ON dots.ExternalNaSequence TO apidb WITH GRANT OPTION;
GRANT REFERENCES ON sres.TaxonName TO apidb;
GRANT SELECT ON sres.TaxonName TO apidb WITH GRANT OPTION;
GRANT REFERENCES ON dots.SnpFeature TO apidb;
GRANT SELECT ON dots.SnpFeature TO apidb WITH GRANT OPTION;
GRANT REFERENCES ON dots.Library TO apidb;
GRANT SELECT ON dots.Library TO apidb WITH GRANT OPTION;
GRANT REFERENCES ON dots.Est TO apidb;
GRANT SELECT ON dots.Est TO apidb WITH GRANT OPTION;
GRANT REFERENCES ON dots.Source TO apidb;
GRANT SELECT ON dots.Source TO apidb WITH GRANT OPTION;
GRANT REFERENCES ON dots.VirtualSequence TO apidb;
GRANT SELECT ON dots.VirtualSequence TO apidb WITH GRANT OPTION;
GRANT REFERENCES ON dots.TranslatedAaFeature TO apidb;
GRANT SELECT ON dots.TranslatedAaFeature TO apidb WITH GRANT OPTION;
GRANT SELECT ON dots.aalocation TO apidb;
GRANT SELECT ON dots.NaFeatureComment TO apidb;
GRANT SELECT ON dots.ExonFeature TO apidb;
GRANT SELECT ON dots.TransmembraneAaFeature TO apidb;
GRANT SELECT ON dots.GeneFeature TO apidb;
GRANT SELECT ON dots.NaLocation TO apidb;
GRANT SELECT ON dots.ExternalNaSequence TO apidb;
GRANT SELECT ON dots.Miscellaneous TO apidb;
GRANT SELECT ON sres.SequenceOntology TO apidb;
GRANT SELECT ON sres.Taxon TO apidb;

---------------------------
-- genes
---------------------------

-- GoTermList mview is used to create GeneAttributes

DROP MATERIALIZED VIEW apidb.GoTermList;

CREATE MATERIALIZED VIEW apidb.GoTermList AS
SELECT gf.source_id, o.ontology, 
       DECODE(gec.name, 'IEA', 'predicted', 'annotated') AS source,
       apidb.tab_to_string(CAST(COLLECT(gt.name) AS apidb.varchartab), ', ') AS go_terms
FROM dots.GeneFeature gf, dots.Transcript t,
     dots.TranslatedAaFeature taf, dots.GoAssociation ga,
     sres.GoTerm gt, dots.GoAssociationInstance gai,
     dots.GoAssociationInstanceLoe gail,
     dots.GoAssocInstEvidCode gaiec, sres.GoEvidenceCode gec,
     (SELECT gr.child_term_id AS go_term_id, gp.name AS ontology
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
  AND gt.go_term_id = o.go_term_id
GROUP BY gf.source_id, o.ontology, 
         DECODE(gec.name, 'IEA', 'predicted', 'annotated');

-- comment this out -- it takes 4 hours to rebuild
--DROP MATERIALIZED VIEW apidb.GeneAttributes1;

CREATE MATERIALIZED VIEW apidb.GeneAttributes1 AS
SELECT gf.source_id,
       REPLACE(so.term_name, '_', ' ') AS gene_type,
       SUBSTR(gf.product, 1, 200) AS product,
       LEAST(nl.start_min, nl.end_max) AS start_min,
       GREATEST(nl.start_min, nl.end_max) AS end_max,
       sns.length AS transcript_length,
       GREATEST(0, least(nl.start_min, nl.end_max) - 5000)
           AS context_start,
       LEAST(sequence.length, greatest(nl.start_min, nl.end_max) + 5000)
           AS context_end,
       DECODE(nvl(nl.is_reversed, 0), 0, 'forward', 1, 'reverse',
              nl.is_reversed) AS strand,
       SUBSTR(sequence.source_id, 1, 50) AS sequence_id,
       SUBSTR(tn.name, 1, 40) AS organism,
       taxon.ncbi_tax_id,
       NVL(protein.tm_domains, 0) AS tm_count,
       so_id, SUBSTR(so.term_name, 1, 150) AS so_term_name,
       SUBSTR(so.definition, 1, 150) AS so_term_definition,
       so.ontology_name, SUBSTR(so.so_version, 1, 7) AS so_version,
       SUBSTR(NVL(rt1.anticodon, rt2.anticodon), 1, 3) AS anticodon,
       protein.molecular_weight,
       protein.isoelectric_point, protein.min_molecular_weight,
       protein.max_molecular_weight, protein.hydropathicity_gravy_score,
       protein.aromaticity_score, protein.cds_length, protein.protein_length,
       protein.ec_numbers,
       ed.name AS external_db_name,
       SUBSTR(edr.version, 1, 10) AS external_db_version,
       exons.exon_count, SUBSTR(cmnt.comment_string, 1, 300) AS comment_string,
       SUBSTR(annotated_go_component.go_terms, 1, 250) AS annotated_go_component,
       SUBSTR(annotated_go_function.go_terms, 1, 250) AS annotated_go_function,
       SUBSTR(annotated_go_process.go_terms, 1, 250) AS annotated_go_process,
       SUBSTR(predicted_go_component.go_terms, 1, 250) AS predicted_go_component,
       SUBSTR(predicted_go_function.go_terms, 1, 250) AS predicted_go_function,
       SUBSTR(predicted_go_process.go_terms, 1, 250) AS predicted_go_process,
       winzeler_expn.winzeler_max_level, winzeler_expn.winzeler_max_pct,
       winzeler_expn.winzeler_max_timing, winzeler_expn.winzeler_min_level,
       winzeler_expn.winzeler_min_timing,
       derisi_expn.derisi_max_level, derisi_expn.derisi_max_pct,
       derisi_expn.derisi_max_timing, derisi_expn.derisi_min_level,
       derisi_expn.derisi_min_timing,
       SUBSTR(sequence.chromosome, 1, 20) AS chromosome,
       sequence.chromosome_order_num
FROM dots.GeneFeature gf, dots.NaLocation nl,
     sres.SequenceOntology so, sres.Taxon,
     sres.TaxonName tn, dots.RnaType rt1, dots.RnaType rt2,
     dots.Transcript t,
     sres.ExternalDatabase ed,
     sres.ExternalDatabaseRelease edr,
     dots.SplicedNaSequence sns,
     apidb.GoTermList annotated_go_component,
     apidb.GoTermList annotated_go_function,
     apidb.GoTermList annotated_go_process,
     apidb.GoTermList predicted_go_component,
     apidb.GoTermList predicted_go_function,
     apidb.GoTermList predicted_go_process,
     (SELECT na_sequence_id, source_id, length, taxon_id, chromosome,
             chromosome_order_num
      FROM dots.ExternalNaSequence
      UNION
      SELECT na_sequence_id, source_id, length, taxon_id, chromosome,
             chromosome_order_num
      FROM dots.VirtualSequence) sequence,
     (SELECT taf.na_feature_id, tas.molecular_weight,
             tas.length AS protein_length,
             greatest(taf.translation_start, taf.translation_stop)
             - least(taf.translation_start, taf.translation_stop) + 1 AS cds_length,
             asa.isoelectric_point,
             asa.min_molecular_weight, asa.max_molecular_weight,
             asa.hydropathicity_gravy_score,
             asa.aromaticity_score, transmembrane.tm_domains,
             ec.ec_numbers
      FROM  dots.TranslatedAaFeature taf,
            dots.TranslatedAaSequence tas,
            apidb.AaSequenceAttribute asa,
            (SELECT aa_sequence_id, max(tm_domains) AS tm_domains
             FROM (SELECT tmaf.aa_sequence_id, COUNT(*) AS tm_domains
                   FROM dots.TransmembraneAaFeature tmaf, dots.AaLocation al
                   WHERE tmaf.aa_feature_id = al.aa_feature_id
                   GROUP BY tmaf.aa_sequence_id) tms
             GROUP BY tms.aa_sequence_id) transmembrane,
            (SELECT aa_sequence_id, 
                    SUBSTR(apidb.tab_to_string(CAST(COLLECT(ec_number)
                                               AS apidb.varchartab), '; '),
                           1, 300)
                      AS ec_numbers
             FROM (SELECT DISTINCT asec.aa_sequence_id,
                          ec.ec_number || ' (' || ec.description || ')' AS ec_number
                   FROM dots.aaSequenceEnzymeClass asec, sres.enzymeClass ec
                   WHERE ec.enzyme_class_id = asec.enzyme_class_id)
             GROUP BY aa_sequence_id) ec
      WHERE taf.aa_sequence_id = tas.aa_sequence_id
        AND taf.aa_sequence_id = asa.aa_sequence_id
        AND tas.aa_sequence_id = transmembrane.aa_sequence_id(+)
        AND tas.aa_sequence_id = ec.aa_sequence_id(+)) protein,
     (SELECT parent_id, count(*) AS exon_count
      FROM dots.ExonFeature
      GROUP BY parent_id) exons,
     (SELECT nfc.na_feature_id,
             MAX(DBMS_LOB.SUBSTR(nfc.comment_string, 300, 1))
               AS comment_string
      FROM dots.NaFeatureComment nfc
      GROUP BY nfc.na_feature_id) cmnt,
     (SELECT p.subject_row_id AS na_feature_id,
             p.max_expression AS derisi_max_level,
             p.max_percentile AS derisi_max_pct,
             p.equiv_max AS derisi_max_timing,
             p.equiv_min AS derisi_min_timing,
             p.min_expression AS derisi_min_level
      FROM apidb.Profile p, apidb.ProfileSet ps, core.TableInfo ti
      WHERE ps.name = 'DeRisi 3D7 Smoothed Averaged'
        AND ti.name = 'GeneFeature'
        AND p.profile_set_id = ps.profile_set_id
        AND ti.table_id = p.subject_table_id) derisi_expn,
     (SELECT p.subject_row_id AS na_feature_id,
             p.max_expression AS winzeler_max_level,
             p.max_percentile AS winzeler_max_pct,
             p.equiv_max AS winzeler_max_timing,
             p.equiv_min AS winzeler_min_timing,
             p.min_expression AS winzeler_min_level
      FROM apidb.Profile p, apidb.ProfileSet ps, core.TableInfo ti
      WHERE ps.name = 'winzeler_cc_sorbExp'
        AND ti.name = 'GeneFeature'
        AND p.profile_set_id = ps.profile_set_id
        AND ti.table_id = p.subject_table_id) winzeler_expn
WHERE gf.na_feature_id = nl.na_feature_id
  AND gf.na_sequence_id = sequence.na_sequence_id
  AND gf.sequence_ontology_id = so.sequence_ontology_id
  AND sequence.taxon_id = taxon.taxon_id
  AND sequence.taxon_id = tn.taxon_id
  AND tn.name_class = 'scientific name'
  AND t.na_feature_id = protein.na_feature_id(+)
  AND t.na_sequence_id = sns.na_sequence_id(+)
  AND gf.sequence_ontology_id = so.sequence_ontology_id
  AND gf.na_feature_id = t.parent_id
  AND t.na_feature_id = rt1.parent_id(+)
  AND gf.na_feature_id = rt2.parent_id(+)
  AND gf.external_database_release_id
       = edr.external_database_release_id
  AND edr.external_database_id = ed.external_database_id
  AND gf.na_feature_id = exons.parent_id(+)
  AND gf.na_feature_id = cmnt.na_feature_id(+)
  AND gf.source_id = annotated_go_component.source_id(+)
  AND 'annotated' = annotated_go_component.source(+)
  AND 'cellular_component' = annotated_go_component.ontology(+)
  AND gf.source_id = annotated_go_function.source_id(+)
  AND 'annotated' = annotated_go_function.source(+)
  AND 'molecular_function' = annotated_go_function.ontology(+)
  AND gf.source_id = annotated_go_process.source_id(+)
  AND 'annotated' = annotated_go_process.source(+)
  AND 'biological_process' = annotated_go_process.ontology(+)
  AND gf.source_id = predicted_go_component.source_id(+)
  AND 'predicted' = predicted_go_component.source(+)
  AND 'cellular_component' = predicted_go_component.ontology(+)
  AND gf.source_id = predicted_go_function.source_id(+)
  AND 'predicted' = predicted_go_function.source(+)
  AND 'molecular_function' = predicted_go_function.ontology(+)
  AND gf.source_id = predicted_go_process.source_id(+)
  AND 'predicted' = predicted_go_process.source(+)
  AND 'biological_process' = predicted_go_process.ontology(+)
  AND gf.na_feature_id = derisi_expn.na_feature_id(+)
  AND gf.na_feature_id = winzeler_expn.na_feature_id(+)
  /* skip toxo predictions */
  AND ed.name NOT IN ('GLEAN predictions', 'GlimmerHMM predictions',
                      'TigrScan', 'tRNAscan-SE', 'TwinScan predictions',
                      'TwinScanEt predictions')
;

GRANT SELECT ON apidb.GeneAttributes1 TO PUBLIC;

CREATE INDEX apidb.GeneAttr_sourceId ON apidb.GeneAttributes1 (source_id);

CREATE OR REPLACE SYNONYM apidb.GeneAttributesSyn
                             FOR apidb.GeneAttributes1;

---------------------------
-- sequences
---------------------------

DROP MATERIALIZED VIEW apidb.SequenceAttributes1;

CREATE MATERIALIZED VIEW apidb.SequenceAttributes1 AS
SELECT SUBSTR(sequence.source_id, 1, 60) AS source_id, sequence.a_count,
       sequence.c_count, sequence.g_count, sequence.t_count,
       (sequence.length
        - (sequence.a_count + sequence.c_count + sequence.g_count + sequence.t_count))
         AS other_count,
       sequence.length,
       to_char((sequence.a_count + sequence.t_count) / sequence.length * 100, '99.99')
         AS at_percent,
       SUBSTR(tn.name, 1, 40) AS organism,
       taxon.ncbi_tax_id,
       SUBSTR(sequence.description, 1, 400) AS sequence_description,
       SUBSTR(genbank.genbank_accession, 1, 20) AS genbank_accession,
       SUBSTR(db.database_version, 1, 30) AS database_version, db.database_name
FROM sres.TaxonName tn, sres.Taxon,
     (SELECT na_sequence_id, taxon_id, source_id, a_count, c_count, g_count,
             t_count, length, description, external_database_release_id
      FROM dots.ExternalNaSequence
      WHERE -- see both? use the VirtualSequence.
            source_id NOT IN (SELECT source_id FROM dots.VirtualSequence)
      UNION
      SELECT na_sequence_id, taxon_id, source_id, a_count, c_count, g_count,
             t_count, length, description, external_database_release_id
      FROM dots.VirtualSequence) sequence,
     (SELECT drns.na_sequence_id, max(dr.primary_identifier) AS genbank_accession
      FROM dots.dbrefNaSequence drns, sres.DbRef dr,
           sres.ExternalDatabaseRelease gb_edr, sres.ExternalDatabase gb_ed
      WHERE drns.db_ref_id = dr.db_ref_id
        AND dr.external_database_release_id
            = gb_edr.external_database_release_id
        AND gb_edr.external_database_id = gb_ed.external_database_id
        AND gb_ed.name = 'GenBank'
      GROUP BY drns.na_sequence_id) genbank,
     (SELECT edr.external_database_release_id,
             edr.version AS database_version, ed.name AS database_name
      FROM sres.ExternalDatabase ed, sres.ExternalDatabaseRelease edr
      WHERE edr.external_database_id = ed.external_database_id) db,
     (SELECT src.na_sequence_id,
             DECODE(src.chromosome, NULL, 'This contig has not been mapped to a chromosome.', 
            'This contig has been mapped to chromosome ' || src.chromosome || '.') AS chromosomemappingtext
      FROM dots.Source src) source
WHERE sequence.taxon_id = tn.taxon_id(+)
  AND tn.name_class = 'scientific name'
  AND sequence.taxon_id = taxon.taxon_id
  AND sequence.na_sequence_id = genbank.na_sequence_id(+)
  AND sequence.external_database_release_id = db.external_database_release_id(+)
  AND sequence.na_sequence_id = source.na_sequence_id(+)
;

GRANT SELECT ON apidb.SequenceAttributes1 TO PUBLIC;

CREATE INDEX apidb.SeqAttr_source_id ON apidb.SequenceAttributes1 (source_id);

CREATE OR REPLACE SYNONYM apidb.SequenceAttributesSyn
                             FOR apidb.SequenceAttributes1;
---------------------------
-- SNPs
---------------------------

DROP MATERIALIZED VIEW apidb.SnpAttributes1;

CREATE MATERIALIZED VIEW apidb.SnpAttributes1 AS
SELECT snp.source_id AS source_id,
       CASE WHEN ed.name = 'Su SNPs' THEN 'NIH SNPs'
       ELSE ed.name END AS dataset,
       CASE WHEN ed.name = 'Su SNPs' THEN 'Su_SNPs'
       WHEN ed.name = 'Broad SNPs' THEN 'Broad_SNPs'
       WHEN ed.name = 'Sanger falciparum SNPs' THEN 'sangerItGhanaSnps'
       WHEN ed.name = 'Sanger reichenowi SNPs' THEN 'sangerReichenowiSnps'
       WHEN ed.name = 'PlasmoDB combined SNPs' THEN 'plasmoDbCombinedSnps'
       END AS dataset_hidden,
       s.source_id AS seq_source_id,
       snp_loc.start_min,
       SUBSTR(snp.reference_strain, 1, 200) AS reference_strain,
       SUBSTR(snp.reference_na, 1, 200) AS reference_na,
       DECODE(snp.is_coding, 0, 'no', 1, 'yes') AS is_coding,
       snp.position_in_CDS,
       snp.position_in_protein,
       SUBSTR(snp.reference_aa, 1, 200) AS reference_aa,
       DECODE(snp.has_nonsynonymous_allele, 0, 'no', 1, 'yes')
         AS has_nonsynonymous_allele,
       SUBSTR(snp.major_allele, 1, 40) AS major_allele,
       SUBSTR(snp.major_product, 1, 40) AS major_product,
       SUBSTR(snp.minor_allele, 1, 40) AS minor_allele,
       SUBSTR(snp.minor_product, 1, 40) AS minor_product,
       snp.major_allele_count, snp.minor_allele_count, snp.strains,
       snp.strains_revcomp,
       gene_info.source_id AS gene_source_id,
       DECODE(gene_info.is_reversed, 0, 'forward', 1, 'reverse')
         AS gene_strand,
       SUBSTR(DBMS_LOB.SUBSTR(s.sequence, 50, snp_loc.start_min - 50), 1, 50)
         AS lflank,
       SUBSTR(DBMS_LOB.SUBSTR(s.sequence, 50, snp_loc.start_min + 1), 1, 50)
         AS rflank,
       SUBSTR(tn.name, 1, 40) AS organism,
       taxon.ncbi_tax_id
FROM dots.ExternalNaSequence s, dots.SnpFeature snp, dots.NaLocation snp_loc,
     sres.ExternalDatabase ed, sres.ExternalDatabaseRelease edr, sres.Taxon,
     sres.TaxonName tn,
     (SELECT gene.source_id, gene_loc.is_reversed, gene.na_feature_id
      FROM dots.GeneFeature gene, dots.NaLocation gene_loc
      WHERE gene.na_feature_id = gene_loc.na_feature_id) gene_info
WHERE edr.external_database_release_id = snp.external_database_release_id
  AND ed.external_database_id = edr.external_database_id
  AND s.na_sequence_id = snp.na_sequence_id
  AND s.taxon_id = taxon.taxon_id
  AND s.taxon_id = tn.taxon_id
  AND tn.name_class = 'scientific name'
  AND snp_loc.na_feature_id = snp.na_feature_id
  AND gene_info.na_feature_id(+) = snp.parent_id;

GRANT SELECT ON apidb.SnpAttributes1 TO PUBLIC;

CREATE INDEX apidb.SnpAttr1_source_id ON apidb.SnpAttributes1 (source_id);

CREATE OR REPLACE SYNONYM apidb.SnpAttributesSyn
                             FOR apidb.SnpAttributes1;
---------------------------
-- ORFs
---------------------------

DROP MATERIALIZED VIEW apidb.OrfAttributes1;

CREATE MATERIALIZED VIEW apidb.OrfAttributes1 AS
SELECT SUBSTR(m.source_id, 1, 60) AS source_id,
       SUBSTR(tn.name, 1, 40) AS organism,
       taxon.ncbi_tax_id,
       SUBSTR(ens.source_id, 1, 30) AS nas_id,
       tas.length,
       nl.start_min, nl.end_max, nl.is_reversed
FROM dots.ExternalNaSequence ens, dots.Miscellaneous m,
     dots.TranslatedAaFeature taaf, dots.TranslatedAaSequence tas,
     sres.Taxon, sres.TaxonName tn, sres.SequenceOntology so,
     dots.NaLocation nl
WHERE m.na_feature_id = taaf.na_feature_id
  AND taaf.aa_sequence_id = tas.aa_sequence_id
  AND ens.na_sequence_id = m.na_sequence_id
  AND ens.taxon_id = tn.taxon_id
  AND ens.taxon_id = taxon.taxon_id
  AND m.sequence_ontology_id = so.sequence_ontology_id
  AND m.na_feature_id = nl.na_feature_id
  AND so.term_name = 'ORF'
  AND tn.name_class='scientific name';

GRANT SELECT ON apidb.OrfAttributes1 TO PUBLIC;

CREATE INDEX apidb.OrfAttr1_source_id ON apidb.OrfAttributes1 (source_id);

CREATE OR REPLACE SYNONYM apidb.OrfAttributesSyn
                             FOR apidb.OrfAttributes1;
---------------------------
-- ESTs
---------------------------

DROP MATERIALIZED VIEW apidb.EstAttributes1;

CREATE MATERIALIZED VIEW apidb.EstAttributes1 AS
SELECT ens.source_id,
       e.seq_primer AS primer,
       ens.a_count,
       ens.c_count,
       ens.g_count,
       ens.t_count,
       (length - (a_count + c_count + g_count + t_count)) AS other_count,
       ens.length,
       l.dbest_name,
       NVL(l.vector, 'unknown') AS vector,
       NVL(l.stage, 'unknown') AS stage,
       SUBSTR(tn.name, 1, 40) AS organism,
       taxon.ncbi_tax_id,
       ed.name AS external_db_name
FROM  dots.Est e,
      dots.ExternalNaSequence ens,
      dots.Library l,
      sres.Taxon,
      sres.TaxonName tn,
      sres.ExternalDatabase ed,
      sres.ExternalDatabaseRelease edr
WHERE e.na_sequence_id = ens.na_sequence_id
AND   e.library_id = l.library_id
AND   ens.taxon_id = tn.taxon_id
AND   ens.taxon_id = taxon.taxon_id
AND   tn.name_class='scientific name'
AND   ens.external_database_release_id = edr.external_database_release_id
AND   edr.external_database_id = ed.external_database_id;

GRANT SELECT ON apidb.EstAttributes1 TO PUBLIC;

CREATE INDEX apidb.EstAttr_source_id ON apidb.EstAttributes1 (source_id);

CREATE OR REPLACE SYNONYM apidb.EstAttributesSyn
                             FOR apidb.EstAttributes1;
---------------------------
-- array elements
---------------------------

DROP MATERIALIZED VIEW apidb.ArrayElementAttributes1;

CREATE MATERIALIZED VIEW apidb.ArrayElementAttributes1 AS
SELECT ens.source_id, ed.name AS provider,
       SUBSTR(tn.name, 1, 40) AS organism,
       taxon.ncbi_tax_id
FROM sres.ExternalDatabase ed, sres.ExternalDatabaseRelease edr,
     dots.ExternalNASequence ens, sres.TaxonName tn, sres.Taxon
WHERE ens.external_database_release_id = edr.external_database_release_id
  AND edr.external_database_id = ed.external_database_id
  AND tn.taxon_id = ens.taxon_id
  AND tn.name_class = 'scientific name'
  AND taxon.taxon_id = ens.taxon_id
;

GRANT SELECT ON apidb.ArrayElementAttributes1 TO PUBLIC;

CREATE INDEX apidb.AEAttr1_source_id
ON apidb.ArrayElementAttributes1 (source_id);

CREATE OR REPLACE SYNONYM apidb.ArrayElementAttributesSyn
                             FOR apidb.ArrayElementAttributes1;
exit
