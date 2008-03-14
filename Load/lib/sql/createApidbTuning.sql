-------------------------------------------------------------------------------
-- createApidbTuning.sql
--
-- includes the former contents of createBfmv.sql (Big F{-at, -reakin',
-- -unctional, -ast} Materialized Views)
--
-- This script creates materialized views which denormalize GUS tables for
-- the sake of performance.  Each record type X has at least an mview named
-- apidb.XAttributes, which has one row for each X record (that is, each
-- distinct source_id for an X), and columns for different attributes.
-- Including an attribute in apidb.XAttributes makes the WDK's query-history
-- column-sorting easy and relatively efficient.
--
-- It is sometimes desirable to change the definition of one of these mviews
-- while it is being used by an application.  Simply dropping and re-creating
-- the materialized view creates a time gap in which the application will
-- fail.  To handle this, we gives the mviews names of the form
-- "apidb.XAttributes1111", then creates a synonym, "apidb.XAttributes", which
-- points to the mview.  To re-run this script while the mviews may be in use,
-- change all occurrences of "1111" to any other four-digit number, for
-- instance "1234".  The application will use the old mview until the "CREATE
-- OR REPLACE SYNONYM" statement runs, and then switch seamlessly to the new.
-- The four-digit synonym is passed as a command-line argument when this script
-- is run.
--
-- A query at the end of this script looks for materialized views that end in
-- a four-digit number but aren't pointed to by a synonym.  For convenience,
-- the query result is in the form of "DROP MATERIALIZED VIEW" statements.  If
-- this script terminates successfully, these statements can be run, dropping
-- the disused mviews.
--
-- This SQL statement will find which four-digit numbers are in use:
-- SELECT * FROM all_synonyms where owner='APIDB';
--
-- This script should be run as the database user APIDB.  Running it as other
-- users has generated "insufficient privilege" errors (even for a user with
-- the DBA privilege).
--
-- Note that apidb requires certain privileges to do this.  Here are examples 
-- (early versions of this script included them, but they've been commented out 
-- since we first started running this as apidb, since you can't grant 
-- privileges to yourself.
-- GRANT CREATE TABLE TO apidb;
-- GRANT CREATE MATERIALIZED VIEW TO apidb;
-- GRANT REFERENCES ON <table> TO apidb;
-- GRANT SELECT ON <table> TO apidb WITH GRANT OPTION;

set time on timing on pagesize 50000 linesize 100 verify off

prompt apidb.GeneAlias;

CREATE MATERIALIZED VIEW apidb.GeneAlias&1 AS
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
                      'TigrScan', 'TwinScan predictions',
                      'TwinScanEt predictions', 'P. falciparum Evigan Gene Models',
                      'Pfalciparum workshop annotations reviewed and changed');

GRANT SELECT ON apidb.GeneAlias&1 TO gus_r;

CREATE INDEX apidb.GeneAlias_gene_idx&1 ON apidb.GeneAlias&1 (gene);
CREATE INDEX apidb.GeneAlias_alias_idx&1 ON apidb.GeneAlias&1 (alias);

--drop materialized view apidb.GeneAlias;

CREATE OR REPLACE SYNONYM apidb.GeneAlias
                          FOR apidb.GeneAlias&1;
-------------------------------------------------------------------------------
prompt apidb.SequenceAlias;

CREATE MATERIALIZED VIEW apidb.SequenceAlias&1 AS
SELECT ens.source_id, LOWER(ens.source_id) AS lowercase_source_id
FROM dots.ExternalNaSequence ens;

CREATE INDEX apidb.SequenceAlias_idx&1 ON apidb.SequenceAlias&1(lowercase_source_id);

GRANT SELECT ON apidb.SequenceAlias&1 TO gus_r;

--drop materialized view apidb.SequenceAlias;

CREATE OR REPLACE SYNONYM apidb.SequenceAlias
                          FOR apidb.SequenceAlias&1;
-------------------------------------------------------------------------------

prompt apidb.GoTermSummary;

CREATE MATERIALIZED VIEW apidb.GoTermSummary&1 AS
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

CREATE INDEX apidb.GoTermSum_sourceId_idx&1 ON apidb.GoTermSummary&1 (source_id);

GRANT SELECT ON apidb.GoTermSummary&1 TO gus_r;

--drop materialized view apidb.GoTermSummary;

CREATE OR REPLACE SYNONYM apidb.GoTermSummary
                          FOR apidb.GoTermSummary&1;
-------------------------------------------------------------------------------

prompt apidb.PdbSimilarity;

CREATE MATERIALIZED VIEW apidb.PdbSimilarity&1 AS
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

CREATE INDEX apidb.PdbSim_sourceId_ix&1
ON apidb.PdbSimilarity&1 (source_id, score DESC);

GRANT SELECT on apidb.PdbSimilarity&1 TO gus_r;

--drop materialized view apidb.PdbSimilarity;

CREATE OR REPLACE SYNONYM apidb.PdbSimilarity
                          FOR apidb.PdbSimilarity&1;
-------------------------------------------------------------------------------

prompt apidb.FeatureLocation;

create materialized view apidb.FeatureLocation&1 as
select case
         when db.name in ('GLEAN predictions', 'GlimmerHMM predictions',
                          'TigrScan', 'TwinScan predictions',
                          'TwinScanEt predictions', -- not 'tRNAscan-SE',
                          'P. falciparum Evigan Gene Models',
                          'Pfalciparum workshop annotations reviewed and changed')
           then 'GenePrediction'
         else nf.subclass_view
       end as feature_type,
       nf.source_id as feature_source_id, ns.source_id as sequence_source_id,
       nf.na_sequence_id, nf.na_feature_id,
       least(nl.start_min, nl.start_max, nl.end_min, nl.end_max) as start_min,
       greatest(nl.start_min, nl.start_max, nl.end_min, nl.end_max) as end_max,
       nl.is_reversed, nf.parent_id, nf.sequence_ontology_id
from dots.NaFeature nf, dots.NaLocation nl, dots.NaSequence ns,
     (select edr.external_database_release_id, ed.name
      from sres.ExternalDatabase ed, sres.ExternalDatabaseRelease edr
      where edr.external_database_id = ed.external_database_id) db
where nf.na_feature_id = nl.na_feature_id
  and nf.external_database_release_id = db.external_database_release_id(+)
  and nf.na_sequence_id = ns.na_sequence_id;

grant select on apidb.FeatureLocation&1 TO gus_r;

create index apidb.featloc_ix&1 on apidb.FeatureLocation&1
             (feature_type, na_sequence_id, start_min, end_max, is_reversed);

create index apidb.featloc2_ix&1 on apidb.FeatureLocation&1
             (na_sequence_id, start_min, end_max, is_reversed, sequence_ontology_id);

--drop materialized view apidb.FeatureLocation;

create or replace synonym apidb.FeatureLocation
                          for apidb.FeatureLocation&1;
-------------------------------------------------------------------------------

prompt apidb.GeneId;

CREATE MATERIALIZED VIEW apidb.GeneId&1 AS
SELECT lower(substr(t.protein_id, 1, instr(t.protein_id, '.') - 1)) AS id,
       gf.source_id AS gene
FROM dots.Transcript t, dots.GeneFeature gf
WHERE t.parent_id = gf.na_feature_id
  AND lower(substr(t.protein_id, 1, instr(t.protein_id, '.') - 1)) IS NOT NULL
UNION
SELECT lower(t.protein_id) AS id,
       gf.source_id AS gene
FROM dots.Transcript t, dots.GeneFeature gf
WHERE t.parent_id = gf.na_feature_id
  AND t.protein_id IS NOT NULL
UNION
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
SELECT lower(dr.primary_identifier) AS id, gf.source_id AS gene
FROM dots.GeneFeature gf, dots.Transcript t, dots.dbrefNaSequence drns,
     sres.DbRef dr, sres.ExternalDatabaseRelease edr,
      sres.ExternalDatabase ed
WHERE gf.na_feature_id = t.parent_id
  AND t.na_sequence_id = drns.na_sequence_id
  AND drns.db_ref_id = dr.db_ref_id
  AND dr.external_database_release_id = edr.external_database_release_id
  AND edr.external_database_id = ed.external_database_id 
  AND ed.name = 'GenBank'
UNION
SELECT LOWER(alias) AS id, gene FROM apidb.GeneAlias
UNION
SELECT pred_loc.feature_source_id AS alias, gene_loc.feature_source_id AS gene
FROM apidb.FeatureLocation gene_loc, apidb.FeatureLocation pred_loc
WHERE pred_loc.feature_type = 'GenePrediction'
  AND gene_loc.feature_type = 'GeneFeature'
  AND pred_loc.na_sequence_id = gene_loc.na_sequence_id
  AND gene_loc.start_min <= pred_loc.end_max
  AND gene_loc.end_max >= pred_loc.start_min
  AND pred_loc.is_reversed = gene_loc.is_reversed
UNION
SELECT lower(pred_loc.feature_source_id) AS alias,
       gene_loc.feature_source_id AS gene
FROM apidb.FeatureLocation gene_loc, apidb.FeatureLocation pred_loc
WHERE pred_loc.feature_type = 'GenePrediction'
  AND gene_loc.feature_type = 'GeneFeature'
  AND pred_loc.na_sequence_id = gene_loc.na_sequence_id
  AND gene_loc.start_min <= pred_loc.end_max
  AND gene_loc.end_max >= pred_loc.start_min
  AND pred_loc.is_reversed = gene_loc.is_reversed;

GRANT SELECT ON apidb.GeneId&1 TO gus_r;

CREATE INDEX apidb.GeneId_gene_idx&1 ON apidb.GeneId&1 (gene);
CREATE INDEX apidb.GeneId_id_idx&1 ON apidb.GeneId&1 (id);

--drop materialized view apidb.GeneId;

CREATE OR REPLACE SYNONYM apidb.GeneId
                          FOR apidb.GeneId&1;
-------------------------------------------------------------------------------

prompt apidb.EpitopeSummary;

CREATE MATERIALIZED VIEW apidb.EpitopeSummary&1 AS
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

GRANT SELECT ON apidb.EpitopeSummary&1 TO gus_r;

CREATE INDEX apidb.Epi_srcId_ix&1 ON apidb.EpitopeSummary&1 (source_id);

--drop materialized view apidb.EpitopeSummary;

CREATE OR REPLACE SYNONYM apidb.EpitopeSummary
                          FOR apidb.EpitopeSummary&1;
-------------------------------------------------------------------------------
prompt apidb.GeneCentromereDistance;

CREATE MATERIALIZED VIEW apidb.GeneCentromereDistance&1 AS
SELECT gfl.feature_source_id AS gene,
       LEAST(ABS(mfl.start_min - gfl.end_max),
             ABS(mfl.end_max - gfl.start_min)) AS centromere_distance,
       gfl.sequence_source_id AS genomic_sequence
FROM apidb.FeatureLocation gfl, apidb.FeatureLocation mfl,
     sres.SequenceOntology so
WHERE gfl.na_sequence_id = mfl.na_sequence_id
  AND mfl.feature_type = 'Miscellaneous'
  AND gfl.feature_type = 'GeneFeature'
  AND mfl.sequence_ontology_id = so.sequence_ontology_id
  AND so.term_name = 'centromere';

GRANT SELECT ON apidb.GeneCentromereDistance&1 TO gus_r;

CREATE INDEX apidb.GCent_loc_ix&1
       ON apidb.GeneCentromereDistance&1 (genomic_sequence, centromere_distance);

--drop materialized view apidb.GeneCentromereDistance;

CREATE OR REPLACE SYNONYM apidb.GeneCentromereDistance
                          FOR apidb.GeneCentromereDistance&1;
-------------------------------------------------------------------------------
prompt apidb.SageTagGene;

create materialized view apidb.SageTagGene&1 as
select t.direction, t.gene_source_id, t.tag_source_id, t.distance,
       t.analysis_id, t.occurrence, t.gene_feature_id, t.tag_feature_id,
       t.tag_count, t.antisense,
       case
         when t.antisense = 0 then t.tag_count
         else 0
       end as sense_count,
       case
         when t.antisense = 0 then 0
         else t.tag_count
       end as antisense_count
from 
  (select '5' as direction, g.feature_source_id AS gene_source_id,
          s.feature_source_id as tag_source_id,
             min (case
                    when g.is_reversed = 1 and s.end_max - g.end_max < 0
                      then 0
                    when g.is_reversed = 1 and s.end_max - g.end_max >= 0
                      then s.end_max - g.end_max
                    when g.is_reversed = 0 and g.start_min - s.start_min < 0
                      then 0
                    when g.is_reversed = 0 and g.start_min - s.start_min >= 0
                      then g.start_min - s.start_min
                  end) as distance,
           dr.analysis_id, max(dr.float_value) as tag_count,
           max(ct.occurrence) as occurrence,
           g.na_feature_id as gene_feature_id, s.na_feature_id as tag_feature_id,
           case when s.is_reversed = g.is_reversed then 0
                else 1
           end as antisense
      from apidb.FeatureLocation g, apidb.FeatureLocation s,
           rad.DataTransformationResult dr,
           (select source_id , count(*) as occurrence
            from dots.SageTagFeature
            group by source_id) ct
      where g.feature_type = 'GeneFeature'
        and s.feature_type = 'SAGETagFeature'
        and g.na_sequence_id = s.na_sequence_id
        and s.feature_source_id = dr.row_id
        and dr.row_id = ct.source_id
        and (case
               when g.is_reversed = 0
                 then g.start_min - s.start_min
               else s.end_max - g.end_max
             end <= 1000
            and case
                  when g.is_reversed = 0
                    then g.end_max - s.end_max
                  else s.start_min - g.start_min
                end >= 0)
      group by g.feature_source_id, s.feature_source_id, dr.analysis_id,
               g.na_feature_id, s.na_feature_id,
               case when s.is_reversed = g.is_reversed then 0
                    else 1
               end
      UNION
      select '3' as direction, g.feature_source_id AS gene_source_id,
             s.feature_source_id as tag_source_id,
             min (case
                    when g.is_reversed = 1 and g.start_min - s.start_min < 0
                      then 0
                    when g.is_reversed = 1 and g.start_min - s.start_min  >= 0
                      then g.start_min - s.start_min
                    when g.is_reversed = 0 and s.end_max - g.end_max < 0
                      then 0
                    when g.is_reversed = 0 and s.end_max - g.end_max >= 0
                      then s.end_max - g.end_max
                  end) as distance,
           dr.analysis_id, max(dr.float_value) as tag_count,
           max(ct.occurrence) as occurrence,
           g.na_feature_id as gene_feature_id, s.na_feature_id as tag_feature_id,
           case when s.is_reversed = g.is_reversed then 0
                else 1
           end as antisense
      from apidb.FeatureLocation g, apidb.FeatureLocation s,
           rad.DataTransformationResult dr,
           (select source_id , count(*) as occurrence
            from dots.SageTagFeature
            group by source_id) ct
            where g.feature_type = 'GeneFeature'
              and s.feature_type = 'SAGETagFeature'
              and g.na_sequence_id = s.na_sequence_id
              and s.feature_source_id = dr.row_id
              and dr.row_id = ct.source_id
              and (case
                     when g.is_reversed = 0
                       then s.end_max - g.end_max
                     else g.start_min - s.start_min end <= 1000
                  and
                   case
                     when g.is_reversed = 0
                       then s.start_min - g.start_min
                     else g.end_max - s.end_max
                   end >= 0)
            group by g.feature_source_id, s.feature_source_id, dr.analysis_id,
                     g.na_feature_id, s.na_feature_id,
                     case when s.is_reversed = g.is_reversed then 0
                          else 1
                     end) t;

grant select on apidb.SageTagGene&1 to gus_r;

--drop materialized view apidb.SageTagGene;

CREATE OR REPLACE SYNONYM apidb.SageTagGene
                          FOR apidb.SageTagGene&1;
-------------------------------------------------------------------------------

-- this should be augmented to include number of elements in library,
-- and the short fixed sequence recognized by the enzyme (e.g. CATG)

create materialized view apidb.SageTagAnalysisAttributes&1 as
select dtr.analysis_id, max(dtr.float_value) as tag_count,
       max(ct.occurrence) as occurrence, substr(st.tag, 1, 30) as sequence,
       st.composite_element_id, a.name as library_name,
       library_total.total_count as library_total_tag_count,
       (max(dtr.float_value) * 100) / library_total.total_count
         as library_tag_percentage,
       r.tag_count as raw_count, tot.total_raw_count,
       100 *(r.tag_count / tot.total_raw_count ) as raw_percent
from dots.SageTagFeature stf, dots.NaLocation nl,
     rad.DataTransformationResult dtr, rad.SageTag st, core.TableInfo ti,
     rad.AnalysisInput ai, rad.LogicalGroup lg, rad.LogicalGroupLink ll,
     rad.Assay a, core.TableInfo quant_ti, --core.DatabaseInfo di,
     rad.SageTagResult r, rad.Quantification q,
     (select source_id , count(*) as occurrence
      from dots.SageTagFeature
      group by source_id) ct,
     (select dt.analysis_id, sum(float_value) as total_count
      from rad.DataTransformationResult dt, rad.Analysis a, rad.Protocol p
      where dt.analysis_id = a.analysis_id
        and a.protocol_id = p.protocol_id
        and p.name = 'Normalization of SAGE tag frequencies to a target total intensity'
      group by dt.analysis_id) library_total,
     (select quantification_id, sum(tag_count) as total_raw_count
      from rad.SageTagResult
      group by quantification_id) tot
where ti.name = 'SAGETag'
  and quant_ti.name = 'Assay'
  --and di.name = 'RAD'
  and dtr.table_id = ti.table_id
  and st.composite_element_id = dtr.row_id
  and stf.source_id = st.composite_element_id
  and st.composite_element_id = r.composite_element_id
  and q.quantification_id = r.quantification_id
  and tot.quantification_id = r.quantification_id
  and nl.na_feature_id = stf.na_feature_id
  and ct.source_id = stf.source_id
  and dtr.analysis_id = ai.analysis_id
  and ai.logical_group_id = lg.logical_group_id
  and lg.logical_group_id = ll.logical_group_id
  and ll.row_id = a.assay_id
  and ll.table_id = quant_ti.table_id
  --and di.database_id = quant_ti.database_id
  and dtr.analysis_id = library_total.analysis_id
group by stf.source_id, dtr.analysis_id, st.tag, st.composite_element_id,
         a.name, library_total.total_count,
         q.name, r.tag_count, tot.total_raw_count;

create index apidb.staa_ix&1 on apidb.SageTagAnalysisAttributes&1 (analysis_id, composite_element_id);

grant select on apidb.SageTagAnalysisAttributes&1 to gus_r;

CREATE OR REPLACE SYNONYM apidb.SageTagAnalysisAttributes
                          FOR apidb.SageTagAnalysisAttributes&1;
---------------------------
-- genes
---------------------------

prompt apidb.GoTermList;

DROP MATERIALIZED VIEW apidb.GoTermList;

CREATE MATERIALIZED VIEW apidb.GoTermList AS
SELECT *
FROM (  -- work around sometime Oracle bug ORA-00942
      SELECT source_id, ontology, source, 
             apidb.tab_to_string(CAST(COLLECT(name) AS apidb.varchartab), ', ')
               AS go_terms
      FROM (SELECT DISTINCT gf.source_id, o.ontology, gt.name,
                  	    DECODE(gail.name, 'Interpro', 'predicted', 'annotated')
                              AS source
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
              AND gt.go_term_id = o.go_term_id)
      GROUP BY source_id, ontology, source);

---------------------------

prompt apidb.GeneGoAttributes;

DROP MATERIALIZED VIEW apidb.GeneGoAttributes;

CREATE MATERIALIZED VIEW apidb.GeneGoAttributes AS
SELECT DISTINCT gene.source_id,
       annotated_go_component.go_terms AS annotated_go_component,
       annotated_go_function.go_terms AS annotated_go_function,
       annotated_go_process.go_terms AS annotated_go_process,
       predicted_go_component.go_terms AS predicted_go_component,
       predicted_go_function.go_terms AS predicted_go_function,
       predicted_go_process.go_terms AS predicted_go_process
FROM (SELECT DISTINCT gene AS source_id FROM apidb.GeneId) gene,
     (SELECT * FROM apidb.GoTermList
      WHERE source = 'annotated' AND ontology = 'cellular_component')
       annotated_go_component,
     (SELECT * FROM apidb.GoTermList
      WHERE source = 'annotated' AND ontology = 'molecular_function')
       annotated_go_function,
     (SELECT * FROM apidb.GoTermList
      WHERE source = 'annotated' AND ontology = 'biological_process')
       annotated_go_process,
     (SELECT * FROM apidb.GoTermList
      WHERE source = 'predicted' AND ontology = 'cellular_component')
       predicted_go_component,
     (SELECT * FROM apidb.GoTermList
      WHERE source = 'predicted' AND ontology = 'molecular_function')
       predicted_go_function,
     (SELECT * FROM apidb.GoTermList
      WHERE source = 'predicted' AND ontology = 'biological_process')
       predicted_go_process
WHERE gene.source_id = annotated_go_component.source_id(+)
  AND 'annotated' = annotated_go_component.source(+)
  AND 'cellular_component' = annotated_go_component.ontology(+)
  AND gene.source_id = annotated_go_function.source_id(+)
  AND 'annotated' = annotated_go_function.source(+)
  AND 'molecular_function' = annotated_go_function.ontology(+)
  AND gene.source_id = annotated_go_process.source_id(+)
  AND 'annotated' = annotated_go_process.source(+)
  AND 'biological_process' = annotated_go_process.ontology(+)
  AND gene.source_id = predicted_go_component.source_id(+)
  AND 'predicted' = predicted_go_component.source(+)
  AND 'cellular_component' = predicted_go_component.ontology(+)
  AND gene.source_id = predicted_go_function.source_id(+)
  AND 'predicted' = predicted_go_function.source(+)
  AND 'molecular_function' = predicted_go_function.ontology(+)
  AND gene.source_id = predicted_go_process.source_id(+)
  AND 'predicted' = predicted_go_process.source(+)
  AND 'biological_process' = predicted_go_process.ontology(+);

GRANT SELECT ON apidb.GeneGoAttributes TO gus_r;

CREATE INDEX apidb.GeneGoAttr_sourceId ON apidb.GeneGoAttributes (source_id);

---------------------------

prompt apidb.DerisiExpn;

DROP MATERIALIZED VIEW apidb.DerisiExpn;

CREATE MATERIALIZED VIEW apidb.DerisiExpn AS
SELECT gene.source_id, expn.derisi_max_level, derisi_max_pct,
       derisi_max_timing, derisi_min_timing, derisi_min_level
FROM (SELECT DISTINCT gene AS source_id from apidb.GeneId) gene,
     (SELECT p.source_id,
             p.max_expression AS derisi_max_level,
             p.max_percentile AS derisi_max_pct,
             p.equiv_max AS derisi_max_timing,
             p.equiv_min AS derisi_min_timing,
             p.min_expression AS derisi_min_level
      FROM apidb.Profile p, apidb.ProfileSet ps, core.TableInfo ti
      WHERE ps.name = 'DeRisi 3D7 Smoothed Averaged'
        AND ti.name = 'GeneFeature'
        AND p.profile_set_id = ps.profile_set_id
        AND ti.table_id = p.subject_table_id) expn
WHERE gene.source_id = expn.source_id(+);

GRANT SELECT ON apidb.DerisiExpn TO gus_r;

CREATE INDEX apidb.Derisi_sourceId ON apidb.DerisiExpn (source_id);

---------------------------

prompt apidb.WinzelerExpn;

DROP MATERIALIZED VIEW apidb.WinzelerExpn;

CREATE MATERIALIZED VIEW apidb.WinzelerExpn AS
SELECT gene.source_id, expn.winzeler_max_level, winzeler_max_pct,
       winzeler_max_timing, winzeler_min_timing, winzeler_min_level
FROM (SELECT DISTINCT gene AS source_id from apidb.GeneId) gene,
     (SELECT p.source_id,
             p.max_expression AS winzeler_max_level,
             p.max_percentile AS winzeler_max_pct,
             p.time_of_max_expr AS winzeler_max_timing,
             p.time_of_min_expr AS winzeler_min_timing,
             p.min_expression AS winzeler_min_level
      FROM apidb.Profile p, apidb.ProfileSet ps, core.TableInfo ti
      WHERE ps.name = 'winzeler_cc_sorbExp'
        AND ti.name = 'GeneFeature'
        AND p.profile_set_id = ps.profile_set_id
        AND ti.table_id = p.subject_table_id) expn
WHERE gene.source_id = expn.source_id(+);

GRANT SELECT ON apidb.WinzelerExpn TO gus_r;

CREATE INDEX apidb.Winzeler_sourceId ON apidb.WinzelerExpn (source_id);

---------------------------

prompt apidb.ToxoExpn;

DROP MATERIALIZED VIEW apidb.ToxoExpn;

CREATE MATERIALIZED VIEW apidb.ToxoExpn AS
SELECT gene.source_id, pru.expression AS pru, veg.expression AS veg,
       rh.expression AS rh, rh_high_glucose.expression AS rh_high_glucose,
       rh_no_glucose.expression AS rh_no_glucose,
       glucose.fold_change AS glucose_fold_change,
       pru_veg.fold_change AS pru_veg_fold_change,
       pru_rh.fold_change AS pru_rh_fold_change,
       veg_rh.fold_change AS veg_rh_fold_change
FROM (SELECT DISTINCT gene AS source_id FROM apidb.GeneAlias) gene,
     (SELECT ga.gene, avg(ep1.mean) AS expression
       FROM rad.LogicalGroup lg, rad.AnalysisInput ai1, rad.Analysis a1,
            rad.ExpressionProfile ep1, rad.Protocol p,
            rad.ShortOligoFamily sof, ApiDB.GeneAlias ga
       WHERE p.name = 'R Expression Statistics'
        AND lg.name = 'Pru - RMA Quantifications'
        AND lg.logical_group_id = ai1.logical_group_id
        AND a1.analysis_id = ai1.analysis_id
        AND a1.protocol_id = p.protocol_id
        AND ep1.analysis_id = a1.analysis_id
        AND sof.composite_element_id = ep1.row_id
          AND sof.source_id is not null
        AND ga.alias = sof.source_id
       GROUP BY ga.gene) pru,
     (SELECT ga.gene, avg(ep1.mean) AS expression
       FROM rad.LogicalGroup lg, rad.AnalysisInput ai1, rad.Analysis a1,
            rad.ExpressionProfile ep1, rad.Protocol p,
            rad.ShortOligoFamily sof, ApiDB.GeneAlias ga
       WHERE p.name = 'R Expression Statistics'
        AND lg.name = 'VEG - RMA Quantifications'
        AND lg.logical_group_id = ai1.logical_group_id
        AND a1.analysis_id = ai1.analysis_id
        AND a1.protocol_id = p.protocol_id
        AND ep1.analysis_id = a1.analysis_id
        AND sof.composite_element_id = ep1.row_id
          AND sof.source_id is not null
        AND ga.alias = sof.source_id
       GROUP BY ga.gene) veg,
     (SELECT ga.gene, avg(ep1.mean) AS expression
       FROM rad.LogicalGroup lg, rad.AnalysisInput ai1, rad.Analysis a1,
            rad.ExpressionProfile ep1, rad.Protocol p,
            rad.ShortOligoFamily sof, ApiDB.GeneAlias ga
       WHERE p.name = 'R Expression Statistics'
        AND lg.name = 'RH - RMA Quantifications'
        AND lg.logical_group_id = ai1.logical_group_id
        AND a1.analysis_id = ai1.analysis_id
        AND a1.protocol_id = p.protocol_id
        AND ep1.analysis_id = a1.analysis_id
        AND sof.composite_element_id = ep1.row_id
          AND sof.source_id is not null
        AND ga.alias = sof.source_id
       GROUP BY ga.gene) rh,
     (SELECT ga.gene, avg(ep1.mean) AS expression
       FROM rad.LogicalGroup lg, rad.AnalysisInput ai1, rad.Analysis a1,
            rad.ExpressionProfile ep1, rad.Protocol p,
            rad.ShortOligoFamily sof, ApiDB.GeneAlias ga
       WHERE p.name = 'R Expression Statistics'
        AND lg.name = 'RH (High Glucose) - RMA Quantifications'
        AND lg.logical_group_id = ai1.logical_group_id
        AND a1.analysis_id = ai1.analysis_id
        AND a1.protocol_id = p.protocol_id
        AND ep1.analysis_id = a1.analysis_id
        AND sof.composite_element_id = ep1.row_id
          AND sof.source_id is not null
        AND ga.alias = sof.source_id
       GROUP BY ga.gene) rh_high_glucose,
     (SELECT ga.gene, avg(ep1.mean) AS expression
       FROM rad.LogicalGroup lg, rad.AnalysisInput ai1, rad.Analysis a1,
            rad.ExpressionProfile ep1, rad.Protocol p,
            rad.ShortOligoFamily sof, ApiDB.GeneAlias ga
       WHERE p.name = 'R Expression Statistics'
        AND lg.name = 'RH (No Glucose) - RMA Quantifications'
        AND lg.logical_group_id = ai1.logical_group_id
        AND a1.analysis_id = ai1.analysis_id
        AND a1.protocol_id = p.protocol_id
        AND ep1.analysis_id = a1.analysis_id
        AND sof.composite_element_id = ep1.row_id
          AND sof.source_id is not null
        AND ga.alias = sof.source_id
       GROUP BY ga.gene) rh_no_glucose,
     (SELECT ga.gene,
              CASE WHEN avg(ep1.mean)/avg(ep2.mean) >= 1
                   THEN avg(ep1.mean)/avg(ep2.mean)
                   ELSE -1/(avg(ep1.mean)/avg(ep2.mean))
                   END AS fold_change
       FROM rad.LogicalGroup lg1, rad.AnalysisInput ai1, rad.Analysis a1,
            rad.ExpressionProfile ep1, rad.LogicalGroup lg2,
            rad.AnalysisInput ai2, rad.Analysis a2,
            rad.ExpressionProfile ep2,
            rad.Protocol p, rad.ShortOligoFamily sof,
            ApiDB.GeneAlias ga
       WHERE p.name = 'R Expression Statistics'
         AND lg1.name = 'RH (No Glucose) - RMA Quantifications'
         AND ai1.logical_group_id = lg1.logical_group_id
         AND a1.analysis_id = ai1.analysis_id
         AND a1.protocol_id = p.protocol_id
         AND ep1.analysis_id = a1.analysis_id
         AND sof.composite_element_id = ep1.row_id
         AND lg2.name = 'RH (High Glucose) - RMA Quantifications'
         AND ai2.logical_group_id = lg2.logical_group_id
         AND a2.analysis_id = ai2.analysis_id
         AND a2.protocol_id = p.protocol_id
         AND ep2.analysis_id = a2.analysis_id
         AND sof.composite_element_id = ep2.row_id
         AND sof.source_id is not null
         AND ga.alias = sof.source_id
        GROUP BY ga.gene) glucose,
     (SELECT ga.gene,
             CASE WHEN avg(ep1.mean)/avg(ep2.mean) >= 1
                            THEN avg(ep1.mean)/avg(ep2.mean)
                            ELSE -1/(avg(ep1.mean)/avg(ep2.mean))
                            END AS fold_change
       FROM rad.LogicalGroup lg1, rad.AnalysisInput ai1, rad.Analysis a1,
            rad.ExpressionProfile ep1, rad.LogicalGroup lg2,
            rad.AnalysisInput ai2, rad.Analysis a2,
            rad.ExpressionProfile ep2,
            rad.Protocol p, rad.ShortOligoFamily sof,
            ApiDB.GeneAlias ga
       WHERE p.name = 'R Expression Statistics'
         AND lg1.name = 'Pru - RMA Quantifications'
         AND ai1.logical_group_id = lg1.logical_group_id
         AND a1.analysis_id = ai1.analysis_id
         AND a1.protocol_id = p.protocol_id
         AND ep1.analysis_id = a1.analysis_id
         AND sof.composite_element_id = ep1.row_id
         AND lg2.name = 'VEG - RMA Quantifications'
         AND ai2.logical_group_id = lg2.logical_group_id
         AND a2.analysis_id = ai2.analysis_id
         AND a2.protocol_id = p.protocol_id
         AND ep2.analysis_id = a2.analysis_id
         AND sof.composite_element_id = ep2.row_id
         AND sof.source_id is not null
         AND ga.alias = sof.source_id
        GROUP BY ga.gene) pru_veg,
     (SELECT ga.gene,
             CASE WHEN avg(ep1.mean)/avg(ep2.mean) >= 1
                            THEN avg(ep1.mean)/avg(ep2.mean)
                            ELSE -1/(avg(ep1.mean)/avg(ep2.mean))
                            END AS fold_change
       FROM rad.LogicalGroup lg1, rad.AnalysisInput ai1, rad.Analysis a1,
            rad.ExpressionProfile ep1, rad.LogicalGroup lg2,
            rad.AnalysisInput ai2, rad.Analysis a2,
            rad.ExpressionProfile ep2,
            rad.Protocol p, rad.ShortOligoFamily sof,
            ApiDB.GeneAlias ga
       WHERE p.name = 'R Expression Statistics'
         AND lg1.name = 'Pru - RMA Quantifications'
         AND ai1.logical_group_id = lg1.logical_group_id
         AND a1.analysis_id = ai1.analysis_id
         AND a1.protocol_id = p.protocol_id
         AND ep1.analysis_id = a1.analysis_id
         AND sof.composite_element_id = ep1.row_id
         AND lg2.name = 'RH - RMA Quantifications'
         AND ai2.logical_group_id = lg2.logical_group_id
         AND a2.analysis_id = ai2.analysis_id
         AND a2.protocol_id = p.protocol_id
         AND ep2.analysis_id = a2.analysis_id
         AND sof.composite_element_id = ep2.row_id
         AND sof.source_id is not null
         AND ga.alias = sof.source_id
        GROUP BY ga.gene) pru_rh,
     (SELECT ga.gene,
             CASE WHEN avg(ep1.mean)/avg(ep2.mean) >= 1
                            THEN avg(ep1.mean)/avg(ep2.mean)
                            ELSE -1/(avg(ep1.mean)/avg(ep2.mean))
                            END AS fold_change
       FROM rad.LogicalGroup lg1, rad.AnalysisInput ai1, rad.Analysis a1,
            rad.ExpressionProfile ep1, rad.LogicalGroup lg2,
            rad.AnalysisInput ai2, rad.Analysis a2,
            rad.ExpressionProfile ep2,
            rad.Protocol p, rad.ShortOligoFamily sof,
            ApiDB.GeneAlias ga
       WHERE p.name = 'R Expression Statistics'
         AND lg1.name = 'VEG - RMA Quantifications'
         AND ai1.logical_group_id = lg1.logical_group_id
         AND a1.analysis_id = ai1.analysis_id
         AND a1.protocol_id = p.protocol_id
         AND ep1.analysis_id = a1.analysis_id
         AND sof.composite_element_id = ep1.row_id
         AND lg2.name = 'RH - RMA Quantifications'
         AND ai2.logical_group_id = lg2.logical_group_id
         AND a2.analysis_id = ai2.analysis_id
         AND a2.protocol_id = p.protocol_id
         AND ep2.analysis_id = a2.analysis_id
         AND sof.composite_element_id = ep2.row_id
         AND sof.source_id is not null
         AND ga.alias = sof.source_id
        GROUP BY ga.gene) veg_rh
WHERE gene.source_id = pru.gene(+)
  AND gene.source_id = veg.gene(+)
  AND gene.source_id = rh.gene(+)
  AND gene.source_id = rh_no_glucose.gene(+)
  AND gene.source_id = rh_high_glucose.gene(+)
  AND gene.source_id = glucose.gene(+)
  AND gene.source_id = pru_veg.gene(+)
  AND gene.source_id = pru_rh.gene(+)
  AND gene.source_id = veg_rh.gene(+);

GRANT SELECT ON apidb.ToxoExpn TO gus_r;

CREATE INDEX apidb.Toxo_sourceId ON apidb.ToxoExpn (source_id);

---------------------------
prompt apidb.GeneProteinAttributes;

DROP MATERIALIZED VIEW apidb.GeneProteinAttributes;

CREATE MATERIALIZED VIEW apidb.GeneProteinAttributes AS
SELECT gene.source_id,
       protein.tm_count, protein.molecular_weight,
       protein.isoelectric_point, protein.min_molecular_weight,
       protein.max_molecular_weight, protein.hydropathicity_gravy_score,
       protein.aromaticity_score, protein.cds_length, protein.protein_length,
       protein.ec_numbers
FROM (SELECT DISTINCT gene AS source_id from apidb.GeneId) gene,
     (SELECT gf.source_id, taf.na_feature_id, tas.molecular_weight,
             tas.length AS protein_length,
             greatest(taf.translation_start, taf.translation_stop)
             - least(taf.translation_start, taf.translation_stop) + 1 AS cds_length,
             asa.isoelectric_point,
             asa.min_molecular_weight, asa.max_molecular_weight,
             asa.hydropathicity_gravy_score,
             asa.aromaticity_score,
             NVL(transmembrane.tm_domains, 0) AS tm_count,
             ec.ec_numbers
      FROM  dots.GeneFeature gf, dots.Transcript t,
            dots.TranslatedAaFeature taf,
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
      WHERE gf.na_feature_id = t.parent_id
        AND t.na_feature_id = taf.na_feature_id
        AND taf.aa_sequence_id = tas.aa_sequence_id
        AND taf.aa_sequence_id = asa.aa_sequence_id
        AND tas.aa_sequence_id = transmembrane.aa_sequence_id(+)
        AND tas.aa_sequence_id = ec.aa_sequence_id(+)) protein
WHERE gene.source_id = protein.source_id(+);

GRANT SELECT ON apidb.GeneProteinAttributes TO gus_r;

CREATE INDEX apidb.GPA_sourceId ON apidb.GeneProteinAttributes (source_id);

---------------------------
prompt apidb.GenomicSequence;

CREATE MATERIALIZED VIEW apidb.GenomicSequence&1 AS
  SELECT ens.na_sequence_id, ens.taxon_id,
         SUBSTR(ens.source_id, 1, 50) AS source_id,
         LOWER(SUBSTR(ens.source_id, 1, 50)) AS lowercase_source_id,
         ens.a_count, ens.c_count, ens.g_count, ens.t_count, ens.length,
         SUBSTR(ens.description, 1, 400) AS description,
         ens.external_database_release_id,
         SUBSTR(ens.chromosome, 1, 40) AS chromosome,
         ens.chromosome_order_num, ens.sequence_ontology_id
  FROM dots.ExternalNaSequence ens, sres.SequenceOntology so
  WHERE ens.sequence_ontology_id = so.sequence_ontology_id
    AND so.term_name != 'EST'
    AND -- see both? use the VirtualSequence.
        ens.source_id IN (SELECT source_id FROM dots.ExternalNaSequence
                         MINUS
                          SELECT source_id FROM dots.VirtualSequence)
UNION
  SELECT na_sequence_id, taxon_id, SUBSTR(source_id, 1, 50) AS source_id,
         LOWER(SUBSTR(source_id, 1, 50)) AS lowercase_source_id,
         a_count, c_count, g_count, t_count, length,
         SUBSTR(description, 1, 400) AS description,
         external_database_release_id, SUBSTR(chromosome, 1, 40) AS chromosome,
         chromosome_order_num, sequence_ontology_id
  FROM dots.VirtualSequence;

GRANT SELECT ON apidb.GenomicSequence&1 TO gus_r;

CREATE INDEX apidb.GS_sourceId&1 ON apidb.GenomicSequence&1 (source_id);
CREATE INDEX apidb.GS_lcSourceId&1 ON apidb.GenomicSequence&1 (lowercase_source_id);
CREATE INDEX apidb.GS_naSeqId&1 ON apidb.GenomicSequence&1 (na_sequence_id);

CREATE OR REPLACE SYNONYM apidb.GenomicSequence
                          FOR apidb.GenomicSequence&1;

---------------------------
prompt apidb.GeneAttributes;

CREATE MATERIALIZED VIEW apidb.GeneAttributes&1 AS
SELECT CASE
         WHEN SUBSTR(tn.name, 1, 6) = 'Crypto'
           THEN 'CryptoDB'
         WHEN SUBSTR(tn.name, 1, 6) = 'Plasmo'
           THEN 'PlasmoDB'
         WHEN SUBSTR(tn.name, 1, 4) = 'Toxo'
           THEN 'ToxoDB'
         WHEN SUBSTR(tn.name, 1, 5) = 'Trich'
           THEN 'TrichDB'
         WHEN SUBSTR(tn.name, 1, 7) = 'Giardia'
           THEN 'GiardiaDB'
         ELSE 'ERROR: setting project in createApidbTuning.sql'
       END as project_id,
       gf.source_id, gf.na_feature_id,
       REPLACE(so.term_name, '_', ' ') AS gene_type,
       SUBSTR(gf.product, 1, 200) AS product,
       gf.is_pseudo,
       LEAST(nl.start_min, nl.start_max, nl.end_min, nl.end_max) AS start_min,
       GREATEST(nl.start_min, nl.start_max, nl.end_min, nl.end_max) AS end_max,
       nl.is_reversed,
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
       so_id, SUBSTR(so.term_name, 1, 150) AS so_term_name,
       SUBSTR(so.definition, 1, 150) AS so_term_definition,
       so.ontology_name, SUBSTR(so.so_version, 1, 7) AS so_version,
       SUBSTR(NVL(rt1.anticodon, rt2.anticodon), 1, 3) AS anticodon,
       protein.tm_count, protein.molecular_weight,
       protein.isoelectric_point, protein.min_molecular_weight,
       protein.max_molecular_weight, protein.hydropathicity_gravy_score,
       protein.aromaticity_score, protein.cds_length, protein.protein_length,
       protein.ec_numbers,
       ed.name AS external_db_name,
       SUBSTR(edr.version, 1, 10) AS external_db_version,
       exons.exon_count, SUBSTR(cmnt.comment_string, 1, 300) AS comment_string,
       SUBSTR(sequence.chromosome, 1, 20) AS chromosome,
       sequence.chromosome_order_num, sequence.na_sequence_id,
       go.annotated_go_component,
       go.annotated_go_function,
       go.annotated_go_process,
       go.predicted_go_component,
       go.predicted_go_function,
       go.predicted_go_process,
       DerisiExpn.derisi_max_level,
       DerisiExpn.derisi_max_pct,
       DerisiExpn.derisi_max_timing,
       DerisiExpn.derisi_min_timing,
       DerisiExpn.derisi_min_level,
       WinzelerExpn.winzeler_max_level,
       WinzelerExpn.winzeler_max_pct,
       WinzelerExpn.winzeler_max_timing,
       WinzelerExpn.winzeler_min_timing,
       WinzelerExpn.winzeler_min_level,
       ToxoExpn.pru, ToxoExpn.veg, ToxoExpn.rh, ToxoExpn.rh_high_glucose,
       ToxoExpn.rh_no_glucose, ToxoExpn.glucose_fold_change,
       ToxoExpn.pru_veg_fold_change, ToxoExpn.pru_rh_fold_change,
       ToxoExpn.veg_rh_fold_change
FROM dots.GeneFeature gf, dots.NaLocation nl,
     sres.SequenceOntology so, sres.Taxon,
     sres.TaxonName tn, dots.RnaType rt1, dots.RnaType rt2,
     dots.Transcript t,
     sres.ExternalDatabase ed,
     sres.ExternalDatabaseRelease edr,
     dots.SplicedNaSequence sns,
     apidb.GeneProteinAttributes protein,
     apidb.GeneGoAttributes go,
     apidb.DerisiExpn DerisiExpn,
     apidb.WinzelerExpn WinzelerExpn,
     apidb.ToxoExpn ToxoExpn,
     apidb.GenomicSequence sequence,
     (SELECT parent_id, count(*) AS exon_count
      FROM dots.ExonFeature
      GROUP BY parent_id) exons,
     (SELECT nfc.na_feature_id,
             MAX(DBMS_LOB.SUBSTR(nfc.comment_string, 300, 1))
               AS comment_string
      FROM dots.NaFeatureComment nfc
      GROUP BY nfc.na_feature_id) cmnt
WHERE gf.na_feature_id = nl.na_feature_id
  AND gf.na_sequence_id = sequence.na_sequence_id
  AND gf.sequence_ontology_id = so.sequence_ontology_id
  AND sequence.taxon_id = taxon.taxon_id
  AND sequence.taxon_id = tn.taxon_id
  AND tn.name_class = 'scientific name'
  AND gf.source_id = protein.source_id(+)
  AND gf.source_id = go.source_id(+)
  AND gf.source_id = DerisiExpn.source_id(+)
  AND gf.source_id = WinzelerExpn.source_id(+)
  AND gf.source_id = ToxoExpn.source_id(+)
  AND t.na_sequence_id = sns.na_sequence_id(+)
  AND gf.na_feature_id = t.parent_id
  AND t.na_feature_id = rt1.parent_id(+)
  AND gf.na_feature_id = rt2.parent_id(+)
  AND gf.external_database_release_id
       = edr.external_database_release_id
  AND edr.external_database_id = ed.external_database_id
  AND gf.na_feature_id = exons.parent_id(+)
  AND gf.na_feature_id = cmnt.na_feature_id(+)
  -- skip toxo predictions (except tRNAs)
  AND (tn.name != 'Toxoplasma gondii'
       OR ed.name NOT IN ('GLEAN predictions', 'GlimmerHMM predictions',
                      'TigrScan', 'TwinScan predictions',
                      'TwinScanEt predictions'))
  -- skip new plasmo annotation
  AND ed.name NOT IN ('P. falciparum Evigan Gene Models',
                      'Pfalciparum workshop annotations reviewed and changed');

GRANT SELECT ON apidb.GeneAttributes&1 TO gus_r;

CREATE INDEX apidb.GeneAttr_sourceId&1
       ON apidb.GeneAttributes&1 (source_id);

CREATE INDEX apidb.GeneAttr_exon_ix&1
       ON apidb.GeneAttributes&1 (exon_count, source_id);

CREATE INDEX apidb.GeneAttr_loc_ix&1
       ON apidb.GeneAttributes&1 (na_sequence_id, start_min, end_max, is_reversed);

CREATE INDEX apidb.GeneAttr_feat_ix&1
       ON apidb.GeneAttributes&1 (na_feature_id);

CREATE OR REPLACE SYNONYM apidb.GeneAttributes
                          FOR apidb.GeneAttributes&1;

---------------------------
-- sequences
---------------------------

prompt apidb.SequenceAttributes;

CREATE MATERIALIZED VIEW apidb.SequenceAttributes&1 AS
SELECT CASE
         WHEN SUBSTR(tn.name, 1, 6) = 'Crypto'
           THEN 'CryptoDB'
         WHEN SUBSTR(tn.name, 1, 6) = 'Plasmo'
           THEN 'PlasmoDB'
         WHEN SUBSTR(tn.name, 1, 4) = 'Toxo'
           THEN 'ToxoDB'
         WHEN SUBSTR(tn.name, 1, 5) = 'Trich'
           THEN 'TrichDB'
         WHEN SUBSTR(tn.name, 1, 7) = 'Giardia'
           THEN 'GiardiaDB'
         ELSE 'ERROR: setting project in createApidbTuning.sql'
       END as project_id,
       SUBSTR(sequence.source_id, 1, 60) AS source_id, sequence.a_count,
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
       SUBSTR(db.database_version, 1, 30) AS database_version, db.database_name,
       SUBSTR(sequence.chromosome, 1, 20) AS chromosome,
       sequence.chromosome_order_num, so.so_id
FROM sres.TaxonName tn, sres.Taxon, sres.SequenceOntology so,
     apidb.GenomicSequence sequence,
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
      WHERE edr.external_database_id = ed.external_database_id) db
WHERE sequence.taxon_id = tn.taxon_id(+)
  AND tn.name_class = 'scientific name'
  AND sequence.taxon_id = taxon.taxon_id
  AND sequence.sequence_ontology_id = so.sequence_ontology_id
  AND so.term_name IN ('chromosome', 'contig', 'supercontig')
  AND sequence.na_sequence_id = genbank.na_sequence_id(+)
  AND sequence.external_database_release_id = db.external_database_release_id(+)
;

GRANT SELECT ON apidb.SequenceAttributes&1 TO gus_r;

CREATE INDEX apidb.SeqAttr_source_id&1 ON apidb.SequenceAttributes&1 (source_id);

CREATE OR REPLACE SYNONYM apidb.SequenceAttributes
                          FOR apidb.SequenceAttributes&1;
---------------------------
-- SNPs
---------------------------

prompt apidb.SnpAttributes;

CREATE MATERIALIZED VIEW apidb.SnpAttributes&1 AS
SELECT CASE
         WHEN SUBSTR(tn.name, 1, 6) = 'Crypto'
           THEN 'CryptoDB'
         WHEN SUBSTR(tn.name, 1, 6) = 'Plasmo'
           THEN 'PlasmoDB'
         WHEN SUBSTR(tn.name, 1, 4) = 'Toxo'
           THEN 'ToxoDB'
         WHEN SUBSTR(tn.name, 1, 5) = 'Trich'
           THEN 'TrichDB'
         WHEN SUBSTR(tn.name, 1, 7) = 'Giardia'
           THEN 'GiardiaDB'
         ELSE 'ERROR: setting project in createApidbTuning.sql'
       END as project_id,
       snp.source_id,
       snp.na_feature_id,
       CASE WHEN ed.name = 'Su SNPs' THEN 'NIH SNPs'
       ELSE ed.name END AS dataset,
       CASE WHEN ed.name = 'Su SNPs' THEN 'Su_SNPs'
       WHEN ed.name = 'Broad SNPs' THEN 'Broad_SNPs'
       WHEN ed.name = 'Sanger falciparum SNPs' THEN 'sangerItGhanaSnps'
       WHEN ed.name = 'Sanger reichenowi SNPs' THEN 'sangerReichenowiSnps'
       WHEN ed.name = 'PlasmoDB combined SNPs' THEN 'plasmoDbCombinedSnps'
       END AS dataset_hidden,
       sequence.na_sequence_id,
       sequence.source_id AS seq_source_id,
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
       snp.major_allele_count, snp.minor_allele_count,
       SUBSTR(snp.strains, 1, 1000) AS strains,
       SUBSTR(snp.strains_revcomp, 1, 1000) AS strains_revcomp,
       gene_info.source_id AS gene_source_id,
       DECODE(gene_info.is_reversed, 0, 'forward', 1, 'reverse')
         AS gene_strand,
       SUBSTR(DBMS_LOB.SUBSTR(ns.sequence, 60, snp_loc.start_min - 60), 1, 60)
         AS lflank,
       SUBSTR(DBMS_LOB.SUBSTR(ns.sequence, 60, snp_loc.start_min + 1), 1, 60)
         AS rflank,
       SUBSTR(tn.name, 1, 40) AS organism,
       taxon.ncbi_tax_id,
       SUBSTR(sequence.chromosome, 1, 20) AS chromosome,
       sequence.chromosome_order_num
FROM dots.NaSequence ns, dots.SnpFeature snp, dots.NaLocation snp_loc,
     sres.ExternalDatabase ed, sres.ExternalDatabaseRelease edr, sres.Taxon,
     sres.TaxonName tn,
     apidb.GenomicSequence sequence,
     (SELECT gene.source_id, gene_loc.is_reversed, gene.na_feature_id
      FROM dots.GeneFeature gene, dots.NaLocation gene_loc
      WHERE gene.na_feature_id = gene_loc.na_feature_id) gene_info
WHERE edr.external_database_release_id = snp.external_database_release_id
  AND ed.external_database_id = edr.external_database_id
  AND ns.na_sequence_id = snp.na_sequence_id
  AND sequence.na_sequence_id = snp.na_sequence_id
  AND sequence.taxon_id = taxon.taxon_id
  AND sequence.taxon_id = tn.taxon_id
  AND tn.name_class = 'scientific name'
  AND snp_loc.na_feature_id = snp.na_feature_id
  AND gene_info.na_feature_id(+) = snp.parent_id;

GRANT SELECT ON apidb.SnpAttributes&1 TO gus_r;

CREATE INDEX apidb.SnpAttr_source_id&1 ON apidb.SnpAttributes&1 (source_id);

CREATE INDEX apidb.Snp_Seq_ix&1
       ON apidb.SnpAttributes&1 (na_sequence_id, dataset, start_min, na_feature_id);

CREATE OR REPLACE SYNONYM apidb.SnpAttributes
                          FOR apidb.SnpAttributes&1;
---------------------------
-- ORFs
---------------------------

prompt apidb.OrfAttributes;

CREATE MATERIALIZED VIEW apidb.OrfAttributes&1 AS
SELECT distinct CASE
         WHEN SUBSTR(tn.name, 1, 6) = 'Crypto'
           THEN 'CryptoDB'
         WHEN SUBSTR(tn.name, 1, 6) = 'Plasmo'
           THEN 'PlasmoDB'
         WHEN SUBSTR(tn.name, 1, 4) = 'Toxo'
           THEN 'ToxoDB'
         WHEN SUBSTR(tn.name, 1, 5) = 'Trich'
           THEN 'TrichDB'
         WHEN SUBSTR(tn.name, 1, 7) = 'Giardia'
           THEN 'GiardiaDB'
         ELSE 'ERROR: setting project in createApidbTuning.sql'
       END as project_id,
       SUBSTR(m.source_id, 1, 60) AS source_id,
       LOWER(SUBSTR(m.source_id, 1, 60)) AS lowercase_source_id,
       SUBSTR(tn.name, 1, 40) AS organism,
       taxon.ncbi_tax_id,
       SUBSTR(sequence.source_id, 1, 30) AS nas_id,
       tas.length,
       nl.start_min, nl.end_max, nl.is_reversed,
       SUBSTR(sequence.chromosome, 1, 20) AS chromosome,
       sequence.chromosome_order_num
FROM dots.Miscellaneous m, dots.TranslatedAaFeature taaf,
     dots.TranslatedAaSequence tas, sres.Taxon, sres.TaxonName tn,
     sres.SequenceOntology so, dots.NaLocation nl,
     (  select gs.na_sequence_id, gs.source_id, gs.chromosome, gs.chromosome_order_num, gs.taxon_id
        from apidb.GenomicSequence gs
      union
        select ens.na_sequence_id, ens.source_id, ens.chromosome, ens.chromosome_order_num, ens.taxon_id
        from dots.ExternalNaSequence ens
        where ens.na_sequence_id in (select distinct na_sequence_id from dots.Miscellaneous
                                  minus select na_sequence_id
                                        from apidb.GenomicSequence)) sequence
WHERE m.na_feature_id = taaf.na_feature_id
  AND taaf.aa_sequence_id = tas.aa_sequence_id
  AND sequence.na_sequence_id = m.na_sequence_id
  AND sequence.taxon_id = tn.taxon_id
  AND sequence.taxon_id = taxon.taxon_id
  AND m.sequence_ontology_id = so.sequence_ontology_id
  AND m.na_feature_id = nl.na_feature_id
  AND so.term_name = 'ORF'
  AND tn.name_class='scientific name';

GRANT SELECT ON apidb.OrfAttributes&1 TO gus_r;

CREATE INDEX apidb.OrfAttr_source_id&1 ON apidb.OrfAttributes&1 (source_id);

CREATE OR REPLACE SYNONYM apidb.OrfAttributes
                        FOR apidb.OrfAttributes&1;
---------------------------
-- ESTs
---------------------------

prompt apidb.EstAttributes;

CREATE MATERIALIZED VIEW apidb.EstAttributes&1 AS
SELECT CASE
         WHEN SUBSTR(tn.name, 1, 6) = 'Crypto'
           THEN 'CryptoDB'
         WHEN SUBSTR(tn.name, 1, 6) = 'Plasmo'
           THEN 'PlasmoDB'
         WHEN SUBSTR(tn.name, 1, 4) = 'Toxo'
           THEN 'ToxoDB'
         WHEN SUBSTR(tn.name, 1, 5) = 'Trich'
           THEN 'TrichDB'
         WHEN SUBSTR(tn.name, 1, 7) = 'Giardia'
           THEN 'GiardiaDB'
         ELSE 'ERROR: setting project in createApidbTuning.sql'
       END as project_id,
       ens.source_id,
       e.seq_primer AS primer,
       ens.a_count,
       ens.c_count,
       ens.g_count,
       ens.t_count,
       (ens.length - (ens.a_count + ens.c_count + ens.g_count + ens.t_count))
         AS other_count,
       ens.length,
       l.dbest_name,
       NVL(l.vector, 'unknown') AS vector,
       NVL(l.stage, 'unknown') AS stage,
       SUBSTR(tn.name, 1, 40) AS organism,
       taxon.ncbi_tax_id,
       ed.name AS external_db_name,
       nvl(best.best_alignment_count, 0) AS best_alignment_count,
       l.library_id, l.dbest_name as library_dbest_name,
       aseq.assembly_na_sequence_id, asm.source_id as assembly_source_id,
       asm.number_of_contained_sequences AS assembly_est_count
FROM dots.Est e, dots.ExternalNaSequence ens, dots.Library l, sres.Taxon,
     sres.TaxonName tn, sres.ExternalDatabase ed,
     sres.ExternalDatabaseRelease edr, sres.SequenceOntology so,
     dots.AssemblySequence aseq, dots.Assembly asm,
     (SELECT query_na_sequence_id, COUNT(*) AS best_alignment_count
      FROM dots.BlatAlignment ba
      WHERE is_best_alignment = 1
      GROUP BY query_na_sequence_id) best
WHERE e.na_sequence_id = ens.na_sequence_id
  AND e.library_id = l.library_id
  AND ens.taxon_id = tn.taxon_id
  AND ens.taxon_id = taxon.taxon_id
  AND tn.name_class='scientific name'
  AND ens.external_database_release_id = edr.external_database_release_id
  AND edr.external_database_id = ed.external_database_id
  AND ens.sequence_ontology_id = so.sequence_ontology_id
  AND so.term_name = 'EST'
  AND best.query_na_sequence_id(+) = ens.na_sequence_id
  AND ens.na_sequence_id = aseq.na_sequence_id(+)
  AND aseq.assembly_na_sequence_id = asm.na_sequence_id(+);

GRANT SELECT ON apidb.EstAttributes&1 TO gus_r;

CREATE INDEX apidb.EstAttr_source_id&1 ON apidb.EstAttributes&1 (source_id);
CREATE INDEX apidb.EstAttr_seqsrc_id&1 ON apidb.EstAttributes&1 (assembly_source_id, source_id);

CREATE OR REPLACE SYNONYM apidb.EstAttributes
                          FOR apidb.EstAttributes&1;

---------------------------
-- assemblies
---------------------------
prompt apidb.AssemblyAttributes;

CREATE MATERIALIZED VIEW apidb.AssemblyAttributes&1 AS
SELECT a.source_id,
       CASE
         WHEN SUBSTR(tn.name, 1, 6) = 'Crypto'
           THEN 'CryptoDB'
         WHEN SUBSTR(tn.name, 1, 6) = 'Plasmo'
           THEN 'PlasmoDB'
         WHEN SUBSTR(tn.name, 1, 4) = 'Toxo'
           THEN 'ToxoDB'
         WHEN SUBSTR(tn.name, 1, 5) = 'Trich'
           THEN 'TrichDB'
         WHEN SUBSTR(tn.name, 1, 7) = 'Giardia'
           THEN 'GiardiaDB'
         ELSE 'ERROR: setting project in createApidbTuning.sql'
       END as project_id,
       tn.name AS organism,
       a.number_of_contained_sequences AS est_count,
       a.length,
       a.a_count,
       a.c_count,
       a.g_count,
       a.t_count,
       a.other_count
FROM  dots.Assembly a, sres.TaxonName tn
WHERE a.taxon_id = tn.taxon_id
  AND tn.name_class = 'scientific name'
;

GRANT SELECT ON apidb.AssemblyAttributes&1 TO gus_r;

CREATE INDEX apidb.AsmAttr_source_id&1
ON apidb.AssemblyAttributes&1 (source_id);

CREATE OR REPLACE SYNONYM apidb.AssemblyAttributes
                          FOR apidb.AssemblyAttributes&1;

---------------------------
-- array elements
---------------------------

prompt apidb.ArrayElementAttributes;

CREATE MATERIALIZED VIEW apidb.ArrayElementAttributes&1 AS
SELECT CASE
         WHEN SUBSTR(tn.name, 1, 6) = 'Crypto'
           THEN 'CryptoDB'
         WHEN SUBSTR(tn.name, 1, 6) = 'Plasmo'
           THEN 'PlasmoDB'
         WHEN SUBSTR(tn.name, 1, 4) = 'Toxo'
           THEN 'ToxoDB'
         WHEN SUBSTR(tn.name, 1, 5) = 'Trich'
           THEN 'TrichDB'
         WHEN SUBSTR(tn.name, 1, 7) = 'Giardia'
           THEN 'GiardiaDB'
         ELSE 'ERROR: setting project in createApidbTuning.sql'
       END as project_id,
       ens.source_id, ed.name AS provider,
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

GRANT SELECT ON apidb.ArrayElementAttributes&1 TO gus_r;

CREATE INDEX apidb.AEAttr_source_id&1
ON apidb.ArrayElementAttributes&1 (source_id);

CREATE OR REPLACE SYNONYM apidb.ArrayElementAttributes
                          FOR apidb.ArrayElementAttributes&1;

---------------------------
-- EstAlignmentGeneSummary
---------------------------

prompt apidb.EstAlignmentGeneSummary;

DROP MATERIALIZED VIEW apidb.EstAlignmentGene;

CREATE MATERIALIZED VIEW apidb.EstAlignmentGene AS
SELECT ba.blat_alignment_id, ba.query_na_sequence_id, e.accession,
         e.library_id, ba.query_taxon_id, ba.target_na_sequence_id,
         ba.target_taxon_id, ba.percent_identity, ba.is_consistent,
         ba.is_best_alignment, ba.is_reversed, ba.target_start, ba.target_end,
         sequence.source_id AS target_sequence_source_id,
         least(ba.target_end, ga.end_max)
         - greatest(ba.target_start, ga.start_min) + 1
           AS est_gene_overlap_length,
         ba.query_bases_aligned / (aseq.sequence_end - aseq.sequence_start + 1)
         * 100 AS percent_est_bases_aligned,
         ga.source_id AS gene
  FROM dots.blatalignment ba, dots.est e, dots.AssemblySequence aseq,
       apidb.GeneAttributes ga, apidb.GenomicSequence sequence,
       dots.NaSequence query_sequence, sres.SequenceOntology so
  WHERE e.na_sequence_id = ba.query_na_sequence_id
    AND aseq.na_sequence_id = ba.query_na_sequence_id
    AND sequence.na_sequence_id = ba.target_na_sequence_id
    AND ga.sequence_id = sequence.source_id
    AND least(ba.target_end, ga.end_max) - greatest(ba.target_start, ga.start_min) >= 0
    AND query_sequence.na_sequence_id = ba.query_na_sequence_id
    AND query_sequence.sequence_ontology_id = so.sequence_ontology_id
    AND so.term_name = 'EST'
    AND ba.target_na_sequence_id = sequence.na_sequence_id;

DROP MATERIALIZED VIEW apidb.EstAlignmentNoGene;

CREATE MATERIALIZED VIEW apidb.EstAlignmentNoGene AS
SELECT * from EstAlignmentGene WHERE 1=0 UNION -- define datatype for null column
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
     dots.NaSequence sequence
WHERE e.na_sequence_id = ba.query_na_sequence_id
  AND aseq.na_sequence_id = ba.query_na_sequence_id
  AND ba.target_na_sequence_id = sequence.na_sequence_id
  AND ba.blat_alignment_id IN
   ( -- set of blat_alignment_ids not in in first leg of UNION
    -- (because they overlap no genes)
    SELECT ba.blat_alignment_id
    FROM dots.BlatAlignment ba, dots.NaSequence query_sequence,
         sres.SequenceOntology so
    WHERE query_sequence.na_sequence_id = ba.query_na_sequence_id
      AND query_sequence.sequence_ontology_id = so.sequence_ontology_id
      AND so.term_name = 'EST'
  MINUS
    SELECT blat_alignment_id FROM apidb.EstAlignmentGene);

CREATE MATERIALIZED VIEW EstAlignmentGeneSummary&1 AS
SELECT * FROM apidb.EstAlignmentNoGene
UNION
SELECT * FROM apidb.EstAlignmentGene;

GRANT SELECT ON apidb.EstAlignmentGeneSummary&1 TO gus_r;

CREATE INDEX apidb.EstSumm_libOverlap_ix&1
             ON apidb.EstAlignmentGeneSummary&1
                (library_id, percent_identity, is_consistent,
                 est_gene_overlap_length, percent_est_bases_aligned);

CREATE INDEX apidb.EstSumm_estSite_ix&1
             ON apidb.EstAlignmentGeneSummary&1
                (target_sequence_source_id, target_start, target_end,
                 library_id);

CREATE OR REPLACE SYNONYM apidb.EstAlignmentGeneSummary
                          FOR apidb.EstAlignmentGeneSummary&1;

-------------------------------------------------------------------------------

CREATE MATERIALIZED VIEW apidb.FeatureSo&1 AS
  SELECT t.na_feature_id, so.sequence_ontology_id, so.term_name
  FROM dots.nafeature gf, dots.nafeature t, sres.sequenceontology so
  WHERE  gf.na_feature_id =  t.parent_id
  AND gf.sequence_ontology_id = so.sequence_ontology_id
UNION
  SELECT na_feature_id, so.sequence_ontology_id, so.term_name
  FROM dots.miscellaneous misc, sres.sequenceontology so
  WHERE misc.sequence_ontology_id = so.sequence_ontology_id;

GRANT SELECT ON apidb.FeatureSo&1 TO gus_r;

CREATE INDEX featso_id_ix&1 ON apidb.FeatureSo&1(na_feature_id);

CREATE OR REPLACE SYNONYM apidb.FeatureSo FOR apidb.FeatureSo&1;

-------------------------------------------------------------------------------

CREATE MATERIALIZED VIEW apidb.polymorphism&1 AS
  SELECT snp.na_feature_id AS snp_na_feature_id,
         snp.source_id AS snp_source_id, sa.na_sequence_id,
         sa.na_feature_id as na_feature_id_a,
         sb.na_feature_id as na_feature_id_b,
         substr(sa.strain, 1, 12) AS strain_a,
         substr(sb.strain, 1, 12) AS strain_b,
         nl.start_min AS start_min,
         snp.external_database_release_id,
         gf.na_feature_id as gene_na_feature_id
  FROM dots.SnpFeature snp, dots.SeqVariation sa, dots.SeqVariation sb,
       dots.NaLocation nl, dots.GeneFeature gf
  WHERE sa.strain < sb.strain
    AND sa.allele != sb.allele
    AND sa.parent_id = sb.parent_id
    AND sa.parent_id = snp.na_feature_id
    AND sa.na_feature_id = nl.na_feature_id
    AND snp.parent_id = gf.na_feature_id (+);
CREATE MATERIALIZED VIEW apidb.polymorphism&1 AS

GRANT SELECT ON apidb.Polymorphism&1 TO gus_r;

CREATE INDEX polymorphism_ix&1 ON apidb.Polymorphism&1(na_sequence_id, strain_a, strain_b, start_min);

CREATE OR REPLACE SYNONYM apidb.Polymorphism FOR apidb.Polymorphism&1;

-------------------------------------------------------------------------------
CREATE MATERIALIZED VIEW apidb.IsolateAttributes&1 AS 
SELECT A.na_sequence_id, A.external_database_release_id, A.source_id,
       A.organism, A.strain, A.specific_host, A.isolation_source, A.country,
       A.note, A.description, A.pcr_primers, A.query_name, A.target_name,
       A.min_subject_start, A.max_subject_end, A.map, B.product, A.project_id,
       A.is_reference, B.product_alias
FROM (SELECT etn.na_sequence_id, etn.external_database_release_id,
             substr(etn.source_id, 1, 20) as source_id,
             substr(src.organism, 1, 60) as organism,
             substr(src.strain || ' ' || src.isolate, 1, 60) as strain,
             substr(src.specific_host || src.lab_host, 1, 50) as specific_host,
             decode(src.isolation_source, null, 'Unknown', 
						        substr(upper(substr(src.isolation_source,0,1))
                    || substr(src.isolation_source,2), 1, 160)) as isolation_source,
             decode(src.country, null, 'Unknown', substr(src.country, 1, 80)) as country,
             substr(src.note, 1, 400) as note,
             substr(etn.description, 1, 400) as description,
             substr(src.pcr_primers, 1, 100) as pcr_primers,
             substr(aln.query_name, 1, 20) as query_name,
             substr(aln.target_name, 1, 20) as target_name,
             aln.min_subject_start, aln.max_subject_end,
             substr(aln.map, 1, 60) as map, 'CryptoDB' as project_id,
             src.is_reference
      FROM dots.ExternalNASequence etn, dots.IsolateSource src,
           sres.ExternalDatabaseRelease edr, sres.ExternalDatabase edb, 
           (SELECT extq.source_id, extq.source_id query_name,
                   extt.source_id target_name,
                   sim.min_subject_start min_subject_start,
                   sim.max_subject_end max_subject_end,
                   extt.source_id || ':' || sim.min_subject_start || '..'
                   || sim.max_subject_end as map
            FROM dots.SIMILARITY sim, dots.EXTERNALNASEQUENCE extt,
                 dots.ExternalNasequence extq,
                 sres.ExternalDatabaseRelease edr,
                 sres.ExternalDatabase edb
            WHERE edr.external_database_id = edb.external_database_id 
              AND edr.external_database_release_id = extq.external_database_release_id 
              AND edb.name = 'Isolates Data' 
              AND edr.version = '2007-12-12' 
              AND sim.query_id = extq.na_sequence_id 
              AND sim.subject_id = extt.na_sequence_id) aln 
      WHERE aln.source_id(+) = etn.source_id
        AND etn.na_sequence_id = src.na_sequence_id
        AND edr.external_database_id = edb.external_database_id
        AND edr.external_database_release_id = etn.external_database_release_id
        AND edb.name = 'Isolates Data'
        AND edr.version = '2007-12-12') A,
     (SELECT etn.source_id,
             substr(apidb.tab_to_string(cast(collect(distinct if.product)
                                        as apidb.varchartab), ' | '), 1, 80)
               as product,
             substr(apidb.tab_to_string(cast(collect(distinct if.product_alias)
                                        as apidb.varchartab), ' | '), 1, 400)
               as product_alias
      FROM dots.ExternalNASequence etn, dots.IsolateFeature if,
           sres.ExternalDatabaseRelease edr, sres.ExternalDatabase edb
      WHERE etn.na_sequence_id = if.na_sequence_id
        AND edr.external_database_id = edb.external_database_id
        AND edr.external_database_release_id = etn.external_database_release_id
        AND edb.name = 'Isolates Data'
        AND edr.version = '2007-12-12'
      GROUP BY etn.source_id) B
WHERE A.source_id = B.source_id(+);

GRANT SELECT ON apidb.IsolateAttributes&1 TO gus_r;

CREATE INDEX apidb.IsolateAttr_sourceId_idx&1 ON apidb.IsolateAttributes&1 (source_id);

CREATE OR REPLACE SYNONYM apidb.IsolateAttributes FOR apidb.IsolateAttributes&1;

-------------------------------------------------------------------------------
CREATE MATERIALIZED VIEW apidb.SageTagAttributes&1 AS
SELECT CASE
         WHEN SUBSTR(tn.name, 1, 6) = 'Crypto'
           THEN 'CryptoDB'
         WHEN SUBSTR(tn.name, 1, 6) = 'Plasmo'
           THEN 'PlasmoDB'
         WHEN SUBSTR(tn.name, 1, 4) = 'Toxo'
           THEN 'ToxoDB'
         WHEN SUBSTR(tn.name, 1, 5) = 'Trich'
           THEN 'TrichDB'
         WHEN SUBSTR(tn.name, 1, 7) = 'Giardia'
           THEN 'GiardiaDB'
         ELSE 'ERROR: setting project in createApidbTuning.sql'
       END as project_id,
       substr(s.source_id || '-' || l.start_min || '-' || l.end_max || '.'
              || l.is_reversed, 1, 40) as source_id,
       f.na_feature_id, f.source_id as feature_source_id,
       substr(s.source_id, 1, 40) as sequence_source_id, s.na_sequence_id,
       l.start_min, l.end_max, substr(st.tag, 1, 20) as sequence,
       st.composite_element_id, st.source_id as rad_source_id,
       l.is_reversed, substr(tn.name, 1, 60) as organism
from dots.SageTagFeature f, dots.NaLocation l, dots.NaSequence s,
     sres.TaxonName tn, rad.SageTag st
where f.na_feature_id = l.na_feature_id
  and s.na_sequence_id = f.na_sequence_id
  and s.taxon_id = tn.taxon_id
  and tn.name_class = 'scientific name'
  and f.source_id = st.composite_element_id;

GRANT SELECT ON apidb.SageTagAttributes&1 TO gus_r;

CREATE INDEX apidb.SageTagAttr_sourceId_idx&1 ON apidb.SageTagAttributes&1
             (source_id);

CREATE INDEX apidb.SageTagAttr_loc_idx&1 ON apidb.SageTagAttributes&1
             (na_sequence_id, start_min, end_max, is_reversed, source_id)

CREATE OR REPLACE SYNONYM apidb.SageTagAttributes FOR apidb.SageTagAttributes&1;

-------------------------------------------------------------------------------

prompt apidb.AsmAlignmentGeneSummary;

DROP MATERIALIZED VIEW apidb.AsmAlignmentGene;

CREATE MATERIALIZED VIEW apidb.AsmAlignmentGene AS
SELECT ba.blat_alignment_id, ba.query_na_sequence_id, a.source_id, a.number_of_contained_sequences AS est_count, a.length,
         ba.query_taxon_id, ba.target_na_sequence_id,
         ba.target_taxon_id, ba.percent_identity, ba.is_consistent,
         ba.is_best_alignment, ba.is_reversed, ba.target_start, ba.target_end,
         sequence.source_id AS target_sequence_source_id,
         least(ba.target_end, ga.end_max)
         - greatest(ba.target_start, ga.start_min) + 1
           AS assembly_gene_overlap_length,
         ba.query_bases_aligned / (query_sequence.length)
         * 100 AS percent_assembly_bases_aligned,
         ga.source_id AS gene
  FROM dots.blatalignment ba, dots.assembly a, 
  apidb.GeneAttributes ga, apidb.GenomicSequence sequence,
       dots.NaSequence query_sequence, sres.SequenceOntology so
  WHERE a.na_sequence_id = ba.query_na_sequence_id
    AND sequence.na_sequence_id = ba.target_na_sequence_id
    AND ga.sequence_id = sequence.source_id
    AND least(ba.target_end, ga.end_max) - greatest(ba.target_start, ga.start_min) >= 0
    AND query_sequence.na_sequence_id = ba.query_na_sequence_id
    AND query_sequence.sequence_ontology_id = so.sequence_ontology_id
    AND so.term_name = 'assembly'
    AND ba.target_na_sequence_id = sequence.na_sequence_id;

DROP MATERIALIZED VIEW apidb.AsmAlignmentNoGene;

CREATE MATERIALIZED VIEW apidb.AsmAlignmentNoGene AS
SELECT * from AsmAlignmentGene WHERE 1=0 UNION -- define datatype for null column
SELECT ba.blat_alignment_id, ba.query_na_sequence_id, a.source_id, a.number_of_contained_sequences AS est_count, a.length,
         ba.query_taxon_id, ba.target_na_sequence_id,
         ba.target_taxon_id, ba.percent_identity, ba.is_consistent,
         ba.is_best_alignment, ba.is_reversed, ba.target_start, ba.target_end,
         sequence.source_id AS target_sequence_source_id,
         NULL
           AS assembly_gene_overlap_length,
         ba.query_bases_aligned / (sequence.length)
         * 100 AS percent_assembly_bases_aligned,
         NULL AS gene
  FROM dots.blatalignment ba, dots.assembly a, 
      dots.NaSequence sequence
  WHERE a.na_sequence_id = ba.query_na_sequence_id
    AND sequence.na_sequence_id = ba.target_na_sequence_id
    AND ba.blat_alignment_id IN
   ( -- set of blat_alignment_ids not in in first leg of UNION
    -- (because they overlap no genes)
    SELECT ba.blat_alignment_id
    FROM dots.BlatAlignment ba, dots.NaSequence query_sequence,
         sres.SequenceOntology so
    WHERE query_sequence.na_sequence_id = ba.query_na_sequence_id
      AND query_sequence.sequence_ontology_id = so.sequence_ontology_id
      AND so.term_name = 'assembly'
  MINUS
    SELECT blat_alignment_id FROM apidb.AsmAlignmentGene);

CREATE MATERIALIZED VIEW AsmAlignmentGeneSummary&1 AS
SELECT * FROM apidb.AsmAlignmentNoGene
UNION
SELECT * FROM apidb.AsmAlignmentGene;

GRANT SELECT ON apidb.AsmAlignmentGeneSummary&1 TO gus_r;

CREATE OR REPLACE SYNONYM apidb.AsmAlignmentGeneSummary
                          FOR apidb.AsmAlignmentGeneSummary&1;

---------------------------
-- cleanup
---------------------------
prompt Run these statements to test synonyms
select 'select count(*) as ' || synonym_name || ' from ' || owner || '.' || synonym_name || ';'
       as "synonym tests"
from all_synonyms
where owner='APIDB';

prompt These mviews appear superfluous (their names end in four digits but no synonym points at them).
prompt Consider dropping them if all synonyms are OK.

SELECT 'drop materialized view ' || owner || '.' || mview_name || ';' AS drops
FROM all_mviews
WHERE mview_name IN (SELECT mview_name
                     FROM all_mviews
                    MINUS
                     SELECT table_name
                     FROM all_synonyms)
  AND REGEXP_REPLACE(mview_name, '[0-9][0-9][0-9][0-9]', 'fournumbers')
      LIKE '%fournumbers';

exit
