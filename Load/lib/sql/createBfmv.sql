set timing on
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

---------------------------
-- genes
---------------------------

-- comment this out -- it takes 4 hours to rebuild
--DROP MATERIALIZED VIEW apidb.GeneAttributes;

--CREATE TABLE apidb.GeneAttributes AS
CREATE MATERIALIZED VIEW apidb.GeneAttributes AS
SELECT gf.source_id,
       REPLACE(so.term_name, '_', ' ') AS gene_type,
       SUBSTR(gf.product, 1, 300) AS product,
       LEAST(nl.start_min, nl.end_max) AS start_min,
       GREATEST(nl.start_min, nl.end_max) AS end_max,
       sns.length AS transcript_length,
       GREATEST(0, least(nl.start_min, nl.end_max) - 5000)
           AS context_start,
       LEAST(sequence.length, greatest(nl.start_min, nl.end_max) + 5000)
           AS context_end,
       DECODE(nvl(nl.is_reversed, 0), 0, 'forward', 1, 'reverse',
              nl.is_reversed) AS strand,
       sequence.source_id AS sequence_id,
       SUBSTR(tn.name, 1, 40) AS organism,
       taxon.ncbi_tax_id,
       NVL(protein.tm_domains, 0) AS tm_count,
       so_id, SUBSTR(so.term_name, 1, 200) AS so_term_name,
       SUBSTR(so.definition, 1, 150) AS so_term_definition,
       so.ontology_name, so.so_version,
       SUBSTR(NVL(rt1.anticodon, rt2.anticodon), 1, 3) AS anticodon,
       protein.molecular_weight,
       protein.isoelectric_point, protein.min_molecular_weight,
       protein.max_molecular_weight, protein.hydropathicity_gravy_score,
       protein.aromaticity_score, protein.cds_length, protein.protein_length,
       ed.name AS external_db_name,
       edr.version AS external_db_version,
       exons.exon_count, cmnt.comment_string,
       SUBSTR(etc.chromosome, 1, 80) AS chromosome,
       SUBSTR(etc.citation,  1, 80) AS citation,
       SUBSTR(etc.protein_id, 1, 80) AS protein_id,
       etc.linkout, etc.molecular_weight_note, etc.dtext, etc.sptext,
       etc.signalp_start, etc.signalp_end
FROM dots.GeneFeature gf, dots.NaLocation nl,
     sres.SequenceOntology so, sres.Taxon,
     sres.TaxonName tn, dots.RnaType rt1, dots.RnaType rt2,
     dots.Transcript t,
     sres.ExternalDatabase ed,
     sres.ExternalDatabaseRelease edr,
     dots.SplicedNaSequence sns,
     (SELECT na_sequence_id, source_id, length, taxon_id
      FROM dots.ExternalNaSequence
      UNION
      SELECT na_sequence_id, source_id, length, taxon_id
      FROM dots.VirtualSequence) sequence,
     (SELECT taf.na_feature_id, tas.molecular_weight,
             tas.length AS protein_length,
             greatest(taf.translation_start, taf.translation_stop)
             - least(taf.translation_start, taf.translation_stop) + 1 AS cds_length,
             asa.isoelectric_point,
             asa.min_molecular_weight, asa.max_molecular_weight,
             asa.hydropathicity_gravy_score,
             asa.aromaticity_score, transmembrane.tm_domains
      FROM  dots.TranslatedAaFeature taf,
            dots.TranslatedAaSequence tas,
            apidb.AaSequenceAttribute asa,
            (SELECT aa_sequence_id, max(tm_domains) AS tm_domains
             FROM (SELECT tmaf.aa_sequence_id, COUNT(*) AS tm_domains
                   FROM dots.TransmembraneAaFeature tmaf, dots.AaLocation al
                   WHERE tmaf.aa_feature_id = al.aa_feature_id
                   GROUP BY tmaf.aa_sequence_id) tms
             GROUP BY tms.aa_sequence_id) transmembrane
      WHERE taf.aa_sequence_id = tas.aa_sequence_id
        AND tas.aa_sequence_id = transmembrane.aa_sequence_id(+)
        AND taf.aa_sequence_id = asa.aa_sequence_id) protein,
     (SELECT parent_id, count(*) AS exon_count
      FROM dots.ExonFeature
      GROUP BY parent_id) exons,
     (SELECT nfc.na_feature_id,
             MAX(dbms_lob.substr(nfc.comment_string, 300, 1))
               AS comment_string
      FROM dots.NaFeatureComment nfc
      GROUP BY nfc.na_feature_id) cmnt,
     (SELECT gf.source_id, s.chromosome, gf.citation, t.protein_id,
            'literal' AS linkout, 'literal' AS molecular_weight_note,
            'literal' AS dtext, 'literal' AS sptext,
            al.start_min AS signalp_start, al.end_max AS signalp_end,
            SUBSTR(gf.citation, 1, 80) AS annotated_go_component,
            SUBSTR(gf.citation, 1, 80) AS annotated_go_function,
            SUBSTR(gf.citation, 1, 80) AS annotated_go_process,
            SUBSTR(gf.citation, 1, 80) AS predicted_go_component,
            SUBSTR(gf.citation, 1, 80) AS predicted_go_function,
            SUBSTR(gf.citation, 1, 80) AS predicted_go_process
      FROM dots.Source s, dots.GeneFeature gf, dots.Transcript t,
           dots.AaLocation al
      WHERE 1=0) etc
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
  AND gf.source_id = etc.source_id(+)
  /* skip toxo predictions */
  AND ed.name NOT IN ('GLEAN predictions', 'GlimmerHMM predictions',
                      'TigrScan', 'tRNAscan-SE', 'TwinScan predictions',
                      'TwinScanEt predictions')
;

GRANT SELECT ON apidb.GeneAttributes TO PUBLIC;

CREATE INDEX apidb.GeneAttr_sourceId ON apidb.GeneAttributes (source_id);

---------------------------
-- sequences
---------------------------

DROP MATERIALIZED VIEW apidb.SequenceAttributes;

CREATE MATERIALIZED VIEW apidb.SequenceAttributes AS
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

GRANT SELECT ON apidb.SequenceAttributes TO PUBLIC;

CREATE INDEX apidb.SeqAttr_source_id ON apidb.SequenceAttributes (source_id);

---------------------------
-- SNPs
---------------------------

DROP MATERIALIZED VIEW apidb.SnpAttributes;

CREATE MATERIALIZED VIEW apidb.SnpAttributes AS
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
       SUBSTR(CASE WHEN gene_info.is_reversed = 1
                   THEN snp.strains_revcomp
                   ELSE snp.strains END, 1, 200) AS description,
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
       SUBSTR(CASE WHEN gene_info.is_reversed = 1
                   THEN apidb.reverse_complement(DBMS_LOB.SUBSTR(s.sequence, 50, snp_loc.start_min + 1))
                   ELSE DBMS_LOB.SUBSTR(s.sequence, 50, snp_loc.start_min - 50)
              END, 1, 50) AS lflank,
       SUBSTR(CASE WHEN gene_info.is_reversed = 1
                   THEN apidb.reverse_complement(DBMS_LOB.SUBSTR(s.sequence, 1, snp_loc.start_min))
                   ELSE DBMS_LOB.SUBSTR(s.sequence, 1, snp_loc.start_min)
              END, 1, 50) AS allele,
       SUBSTR(CASE WHEN gene_info.is_reversed = 1
                   THEN apidb.reverse_complement(DBMS_LOB.SUBSTR(s.sequence, 50, snp_loc.start_min - 50))
                   ELSE DBMS_LOB.SUBSTR(s.sequence, 50, snp_loc.start_min + 1)
              END, 1, 50) AS rflank,
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

GRANT SELECT ON apidb.SnpAttributes TO PUBLIC;

CREATE INDEX apidb.SnpAttr_source_id ON apidb.SnpAttributes (source_id);

---------------------------
-- ORFs
---------------------------

DROP MATERIALIZED VIEW apidb.OrfAttributes;

CREATE MATERIALIZED VIEW apidb.OrfAttributes AS
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

GRANT SELECT ON apidb.OrfAttributes TO PUBLIC;

CREATE INDEX apidb.OrfAttr_source_id ON apidb.OrfAttributes (source_id);

---------------------------
-- ESTs
---------------------------

DROP MATERIALIZED VIEW apidb.EstAttributes;

CREATE MATERIALIZED VIEW apidb.EstAttributes AS
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

GRANT SELECT ON apidb.EstAttributes TO PUBLIC;

CREATE INDEX apidb.EstAttr_source_id ON apidb.EstAttributes (source_id);

---------------------------
-- array elements
---------------------------

DROP MATERIALIZED VIEW apidb.ArrayElementAttributes;

CREATE MATERIALIZED VIEW apidb.ArrayElementAttributes AS
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

GRANT SELECT ON apidb.ArrayElementAttributes TO PUBLIC;

CREATE INDEX apidb.AEAttr_source_id
ON apidb.ArrayElementAttributes (source_id);

exit
