-- schema changes for GUS tables

ALTER TABLE DOTS.RNAFEATUREEXON
    ADD CODING_START numeric(12),
    ADD CODING_END numeric(12)
;
-- indexes on GUS tables
CREATE INDEX aasequenceimp_string2_ix ON dots.aasequenceimp (string2, aa_sequence_id);

CREATE INDEX nasequenceimp_string1_seq_ix ON dots.nasequenceimp (string1, external_database_release_id, na_sequence_id);

CREATE INDEX nasequenceimp_string1_ix ON dots.nasequenceimp (string1, na_sequence_id);

CREATE INDEX rfe_rnaexix ON dots.rnafeatureexon (rna_feature_id, exon_feature_id);

-- for the tuning manager, which decides whether an input table has changed
-- by finding its record count and max(modification_date)
CREATE INDEX nf_submod_ix ON dots.nafeatureimp (subclass_view, modification_date, na_feature_id);

CREATE INDEX af_submod_ix ON dots.aafeatureimp (subclass_view, modification_date, aa_feature_id);

CREATE INDEX ns_submod_ix ON dots.nasequenceimp (subclass_view, modification_date, na_sequence_id);

CREATE INDEX as_submod_ix ON dots.aasequenceimp (subclass_view, modification_date, aa_sequence_id);

CREATE INDEX char_info_ix ON study.characteristic (protocol_app_node_id, qualifier_id, unit_id, table_id, characteristic_id, ontology_term_id, value);


CREATE INDEX aal_mod_ix ON dots.aalocation (modification_date, aa_location_id);
CREATE INDEX asmseq_mod_ix ON dots.assemblysequence (modification_date, assembly_sequence_id);
CREATE INDEX ba_mod_ix ON dots.blatalignment (modification_date, blat_alignment_id);
CREATE INDEX drnf_mod_ix ON dots.dbrefaafeature (modification_date, db_ref_aa_feature_id);
CREATE INDEX draf_mod_ix ON dots.dbrefnafeature (modification_date, db_ref_na_feature_id);
CREATE INDEX est_mod_ix ON dots.est (modification_date, est_id);
CREATE INDEX gi_mod_ix ON dots.geneinstance (modification_date, gene_instance_id);
CREATE INDEX ga_mod_ix ON dots.goassociation (modification_date, go_association_id);
CREATE INDEX gai_mod_ix ON dots.goassociationinstance (modification_date, go_association_instance_id);
CREATE INDEX gaec_mod_ix ON dots.goassocinstevidcode (modification_date, go_assoc_inst_evid_code_id);
CREATE INDEX nfc_mod_ix ON dots.nafeaturecomment (modification_date, na_feature_comment_id);
CREATE INDEX nfng_mod_ix ON dots.nafeaturenagene (modification_date, na_feature_na_gene_id);
CREATE INDEX ng_mod_ix ON dots.nagene (modification_date, na_gene_id);
CREATE INDEX nal_mod_ix ON dots.nalocation (modification_date, na_location_id);
CREATE INDEX sp_mod_ix ON dots.sequencepiece (modification_date, sequence_piece_id);
CREATE INDEX ssg_mod_ix ON dots.sequencesequencegroup (modification_date, sequence_sequence_group_id);
CREATE INDEX sim_mod_ix ON dots.similarity (modification_date, similarity_id);
CREATE INDEX simspan_mod_ix ON dots.similarityspan (modification_date, similarity_span_id);

CREATE INDEX dbref_mod_ix ON sres.dbref (modification_date, db_ref_id);
CREATE INDEX tx_mod_ix ON sres.taxon (modification_date, taxon_id);
CREATE INDEX txname_mod_ix ON sres.taxonname (modification_date, taxon_name_id);


-- for OrthoMCL:
-- string1 = secondary_identifier = full_id
CREATE INDEX lwrfullid_ix ON dots.aasequenceimp (lower(string1), aa_sequence_id, string1);
CREATE INDEX lwrsrcid_ix ON dots.aasequenceimp(lower(source_id), aa_sequence_id, string1);
CREATE INDEX lwrrefprim_ix ON sres.dbref (lower(primary_identifier), db_ref_id, external_database_release_id);
CREATE INDEX lwrrefsec_ix ON sres.dbref (lower(secondary_identifier), db_ref_id, external_database_release_id);

-- constrain NaSequence source_ids to be unique
ALTER TABLE DOTS.NASEQUENCEIMP ADD CONSTRAINT SOURCE_ID_UNIQ UNIQUE (SOURCE_ID);

-- TODO IS THIS COMPATIBLE WITH POSTGRES??
-- have Oracle create optimizer stats for the column pair (subclass_view, external_database_release_id)
--select dbms_stats.create_extended_stats('DOTS', 'NAFEATUREIMP', '(SUBCLASS_VIEW, EXTERNAL_DATABASE_RELEASE_ID)') from dual;

--------------------------------------------------------------------------------

-- TODO ARE THESE COMPATIBLE WITH POSTGRES??
-- upgrade GUS_W to support CTXSYS indexes (Oracle Text)
-- GRANT EXECUTE ON CTXSYS.CTX_CLS TO GUS_W;
-- GRANT EXECUTE ON CTXSYS.CTX_DDL TO GUS_W;
-- GRANT EXECUTE ON CTXSYS.CTX_DOC TO GUS_W;
-- GRANT EXECUTE ON CTXSYS.CTX_OUTPUT TO GUS_W;
-- GRANT EXECUTE ON CTXSYS.CTX_QUERY TO GUS_W;
-- GRANT EXECUTE ON CTXSYS.CTX_REPORT TO GUS_W;
-- GRANT EXECUTE ON CTXSYS.CTX_THES TO GUS_W;
-- GRANT EXECUTE ON CTXSYS.CTX_ULEXER TO GUS_W;
-- GRANT EXECUTE ON CTXSYS.DRUE TO GUS_W;
-- GRANT EXECUTE ON CTXSYS.CATINDEXMETHODS TO GUS_W;
-- GRANT CREATE INDEXTYPE to GUS_W;
-- GRANT CREATE PROCEDURE to GUS_W;
-- GRANT CREATE SEQUENCE to GUS_W;
-- GRANT CREATE SESSION to GUS_W;
-- GRANT CREATE SYNONYM to GUS_W;
-- GRANT CREATE TABLE to GUS_W;
-- GRANT CREATE TRIGGER to GUS_W;
-- GRANT CREATE TYPE to GUS_W;
-- GRANT CREATE VIEW to GUS_W;
 
-- GRANTs required for CTXSYS
-- TODO CAN'T GRANT TO schema
-- GRANT CONNECT, RESOURCE, CTXAPP, GUS_W to core;
-- GRANT CONNECT, RESOURCE, CTXAPP, GUS_W to dots;

-- GRANT CONNECT, RESOURCE, CTXAPP, GUS_W to study;
-- GRANT CONNECT, RESOURCE, CTXAPP, GUS_W to sres;

--- TODO IS THIS COMPATIBLE WITH POSTGRES??
-- for v$ selects, which are needed by org.gusdb.fgputil.db.ConnectionWrapper to
-- check for uncommitted transactions before returning connections to the pool.
-- GRANT SELECT_CATALOG_ROLE TO GUS_R;

-- indexes to help queries against SnpFeature
-- (and some ALTER TABLE statements to make the indexes possible;
--  Oracle wants index keys no bigger than about 6K bytes)

-- TODO !!!! FAILS, ERROR:  cannot alter type of a column used by a view or rule
-- TODO MAYBE NOT NEEDED IF THE FOLLOWING ONES WORK
-- alter table dots.NaFeatureImp
--       modify (string8 varchar(1500),
--               string9 varchar(1500),
--               string12 varchar(1500),
--               string18 varchar(1500));

CREATE INDEX snpstrain_ix ON dots.nafeatureimp (subclass_view, string9, string8, number3, float2, float3, parent_id, string12, string18, na_feature_id);
CREATE INDEX snpdiff_ix ON dots.nafeatureimp (subclass_view, parent_id, string18, string9, number3, float2, float3, string12, na_feature_id);

CREATE INDEX nafeat_scseqfeat_ix ON dots.nafeatureimp (subclass_view, na_sequence_id, na_feature_id);
CREATE INDEX nafeat_subso_ix ON dots.nafeatureimp (subclass_view, sequence_ontology_id, na_feature_id);


-- add this to prevent race condition in which we write duplicate rows
-- when plugins first run in a workflow on a brand new instance
ALTER TABLE core.algorithmimplementation ADD CONSTRAINT alg_imp_uniq UNIQUE (executable, cvs_revision, executable_md5);


-- add columns to a GUS view
-- drop first, because this view already exists from GUS install
-- (and don't drop in dropGusTuning.sql)

ALTER TABLE dots.aafeatureimp ADD mass_spec_summary_id numeric(12);

DROP VIEW IF EXISTS DOTS.MASSSPECFEATURE;
CREATE OR REPLACE VIEW DOTS.MASSSPECFEATURE AS
SELECT AA_FEATURE_ID,
  AA_SEQUENCE_ID,
  FEATURE_NAME_ID,
  PARENT_ID,
  NA_FEATURE_ID,
  SUBCLASS_VIEW,
  SEQUENCE_ONTOLOGY_ID,
  DESCRIPTION,
  PFAM_ENTRY_ID,
  MOTIF_AA_SEQUENCE_ID,
  REPEAT_TYPE_ID,
  EXTERNAL_DATABASE_RELEASE_ID,
  SOURCE_ID,
  PREDICTION_ALGORITHM_ID,
  IS_PREDICTED,
  REVIEW_STATUS_ID,
  STRING1 AS DEVELOPMENTAL_STAGE,
  NUMBER1 AS SPECTRUM_COUNT,
  MASS_SPEC_SUMMARY_ID,
  MODIFICATION_DATE,
  USER_READ,
  USER_WRITE,
  GROUP_READ,
  GROUP_WRITE,
  OTHER_READ,
  OTHER_WRITE,
  ROW_USER_ID,
  ROW_GROUP_ID,
  ROW_PROJECT_ID,
  ROW_ALG_INVOCATION_ID
FROM DoTS.AAFeatureImp
WHERE subclass_view='MassSpecFeature';


GRANT SELECT ON DOTS.MASSSPECFEATURE TO gus_r;
GRANT INSERT, UPDATE, DELETE ON DOTS.MASSSPECFEATURE TO gus_w;

ALTER TABLE study.protocolappnode ADD isa_type varchar(50);
ALTER TABLE study.protocolappnode ADD node_order_num numeric(10);
ALTER TABLE results.familyexpression ADD percentile_channel1 float8;
ALTER TABLE results.geneexpression ADD percentile_channel1 float8;
ALTER TABLE results.nafeatureexpression ADD percentile_channel1 float8;
ALTER TABLE results.reporterexpression ADD percentile_channel1 float8;
ALTER TABLE results.rnaexpression ADD percentile_channel1 float8;
ALTER TABLE results.familyexpression ADD percentile_channel2 float8;
ALTER TABLE results.geneexpression ADD percentile_channel2 float8;
ALTER TABLE results.nafeatureexpression ADD percentile_channel2 float8;
ALTER TABLE results.reporterexpression ADD percentile_channel2 float8;
ALTER TABLE results.rnaexpression ADD percentile_channel2 float8;

CREATE INDEX pan_info_ix ON study.protocolappnode (protocol_app_node_id, isa_type, type_id, name, external_database_release_id, source_id, subtype_id, node_order_num);

ALTER TABLE results.NaFeatureDiffResult ADD confidence float8;

ALTER TABLE dots.GoAssocInstEvidCode ADD reference varchar(500);
ALTER TABLE dots.GoAssocInstEvidCode ADD evidence_code_parameter varchar(2000);

--------------------------------------------------------------------------------
CREATE TABLE RESULTS.REPORTERINTENSITY
  (
    REPORTER_INTENSITY_ID numeric(12) not null,
    PROTOCOL_APP_NODE_ID  numeric(10) not null,
    REPORTER_ID           numeric(12) not null,
    value                 float8,
    CONFIDENCE            float8,
    STANDARD_ERROR        float8,
    CATEGORICAL_VALUE     varchar(100),
    MODIFICATION_DATE     date not null,
    USER_READ             numeric(1) not null,
    USER_WRITE            numeric(1) not null,
    GROUP_READ            numeric(1) not null,
    GROUP_WRITE           numeric(1) not null,
    OTHER_READ            numeric(1) not null,
    OTHER_WRITE           numeric(1) not null,
    ROW_USER_ID           numeric(12) not null,
    ROW_GROUP_ID          numeric(4) not null,
    ROW_PROJECT_ID        numeric(4) not null,
    ROW_ALG_INVOCATION_ID numeric(12) not null,
    FOREIGN KEY (PROTOCOL_APP_NODE_ID) REFERENCES STUDY.PROTOCOLAPPNODE,
    FOREIGN KEY (REPORTER_ID) REFERENCES PLATFORM.REPORTER,
    PRIMARY KEY (REPORTER_INTENSITY_ID)
  );

CREATE INDEX rptrintsty_revix0 ON results.reporterintensity (protocol_app_node_id, reporter_id, value, reporter_intensity_id);

CREATE SEQUENCE RESULTS.REPORTERINTENSITY_SQ;

GRANT insert, select, update, delete ON  RESULTS.REPORTERINTENSITY TO gus_w;
GRANT select ON RESULTS.REPORTERINTENSITY TO gus_r;
GRANT select ON RESULTS.REPORTERINTENSITY_sq TO gus_w;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     ROW_ALG_INVOCATION_ID)
SELECT NEXTVAL('CORE.TABLEINFO_SQ'), 'ReporterIntensity',
       'Standard', 'reporter_intensity_id',
       d.database_id, 0, 0, NULL, NULL, 1,localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (select DATABASE_ID from CORE.DATABASEINFO where name = 'Results') d
WHERE 'reporterintensity' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    where DATABASE_ID = D.DATABASE_ID)
;


--------------------------------------------------------------------------------
CREATE TABLE Results.CompoundMassSpec
  (
    compound_mass_spec_id numeric(12) not null,
    PROTOCOL_APP_NODE_ID  numeric(10) not null,
    compound_id           numeric(12) not null,
    value                 float8,
    STANDARD_ERROR        float8,
    isotopomer            varchar(100),
    MODIFICATION_DATE     date not null,
    USER_READ             numeric(1) not null,
    USER_WRITE            numeric(1) not null,
    GROUP_READ            numeric(1) not null,
    GROUP_WRITE           numeric(1) not null,
    OTHER_READ            numeric(1) not null,
    OTHER_WRITE           numeric(1) not null,
    ROW_USER_ID           numeric(12) not null,
    ROW_GROUP_ID          numeric(4) not null,
    ROW_PROJECT_ID        numeric(4) not null,
    ROW_ALG_INVOCATION_ID numeric(12) not null,
    FOREIGN KEY (protocol_app_node_id) REFERENCES study.protocolappnode,
    PRIMARY KEY (compound_mass_spec_id)
  );

CREATE INDEX cms_revix0 ON results.compoundmassspec (protocol_app_node_id, compound_mass_spec_id);

create sequence RESULTS.CompoundMassSpec_SQ;

GRANT insert, select, update, delete ON  RESULTS.CompoundMassSpec TO gus_w;
GRANT select ON RESULTS.CompoundMassSpec TO gus_r;
GRANT select ON RESULTS.CompoundMassSpec_sq TO gus_w;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     ROW_ALG_INVOCATION_ID)
SELECT NEXTVAL('CORE.TABLEINFO_SQ'), 'CompoundMassSpec',
       'Standard', 'compound_mass_spec_id',
       d.database_id, 0, 0, NULL, NULL, 1,localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (select DATABASE_ID from CORE.DATABASEINFO where name = 'Results') d
WHERE 'compoundmassspec' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    where DATABASE_ID = D.DATABASE_ID)
;

-----------------------------------------------------------------------------

create table RESULTS.NAFeatureHostResponse
  (
    NA_FEATURE_HOST_RESPONSE_ID numeric(12) not null,
    PROTOCOL_APP_NODE_ID   numeric(10) not null,
    na_feature_ID            numeric(12) not null,
    value                 float8,
    MODIFICATION_DATE     date not null,
    USER_READ             numeric(1) not null,
    USER_WRITE            numeric(1) not null,
    GROUP_READ            numeric(1) not null,
    GROUP_WRITE           numeric(1) not null,
    OTHER_READ            numeric(1) not null,
    OTHER_WRITE           numeric(1) not null,
    ROW_USER_ID           numeric(12) not null,
    ROW_GROUP_ID          numeric(4) not null,
    ROW_PROJECT_ID        numeric(4) not null,
    ROW_ALG_INVOCATION_ID numeric(12) not null,
    foreign key (PROTOCOL_APP_NODE_ID) references STUDY.PROTOCOLAPPNODE,
    foreign key (NA_FEATURE_ID) references DoTS.NAFeatureImp,
    primary key (NA_FEATURE_HOST_RESPONSE_ID)
  );

CREATE SEQUENCE RESULTS.NAFEATUREHOSTRESPONSE_SQ;

GRANT insert, select, update, delete ON  RESULTS.NAFEATUREHOSTRESPONSE TO gus_w;
GRANT select ON RESULTS.NAFEATUREHOSTRESPONSE TO gus_r;
GRANT select ON RESULTS.NAFEATUREHOSTRESPONSE_sq TO gus_w;

CREATE INDEX nfhr_revix0 ON results.nafeaturehostresponse (protocol_app_node_id, na_feature_host_response_id);

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     ROW_ALG_INVOCATION_ID)
SELECT NEXTVAL('CORE.TABLEINFO_SQ'), 'NaFeatureHostResponse',
       'Standard', 'na_feature_host_response_id',
       d.database_id, 0, 0, NULL, NULL, 1,localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (select DATABASE_ID from CORE.DATABASEINFO where name = 'Results') D
WHERE 'nafeaturehostresponse' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    where DATABASE_ID = D.DATABASE_ID);

--------------------------------------------------------------------------------

--GRANT REFERENCES on sres.taxon to results;

--------------------------------------------------------------------------------

CREATE TABLE Results.LineageAbundance
  (
    lineage_abundance_id    numeric(12) not null,
    PROTOCOL_APP_NODE_ID  numeric(10) not null,
    lineage             varchar(254) not null,
    raw_count                  numeric(20),
    relative_abundance         float8,
    MODIFICATION_DATE     date not null,
    USER_READ             numeric(1) not null,
    USER_WRITE            numeric(1) not null,
    GROUP_READ            numeric(1) not null,
    GROUP_WRITE           numeric(1) not null,
    OTHER_READ            numeric(1) not null,
    OTHER_WRITE           numeric(1) not null,
    ROW_USER_ID           numeric(12) not null,
    ROW_GROUP_ID          numeric(4) not null,
    ROW_PROJECT_ID        numeric(4) not null,
    ROW_ALG_INVOCATION_ID numeric(12) not null,
    foreign key (PROTOCOL_APP_NODE_ID) references STUDY.PROTOCOLAPPNODE,
    primary key (lineage_abundance_id)
  );

CREATE SEQUENCE RESULTS.LineageAbundance_SQ;

GRANT insert, select, update, delete ON  RESULTS.LineageAbundance TO gus_w;
GRANT select ON RESULTS.LineageAbundance TO gus_r;
GRANT select ON RESULTS.LineageAbundance_sq TO gus_w;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     ROW_ALG_INVOCATION_ID)
SELECT NEXTVAL('CORE.TABLEINFO_SQ'), 'LineageAbundance',
       'Standard', 'lineage_abundance_id',
       d.database_id, 0, 0, NULL, NULL, 1,localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (select DATABASE_ID from CORE.DATABASEINFO where name = 'Results') D
WHERE 'lineageabundance' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    where DATABASE_ID = D.DATABASE_ID)
;

CREATE INDEX lineageabun_revix1 ON results.lineageabundance (protocol_app_node_id, lineage_abundance_id);
CREATE INDEX lineageabun_revix2 ON results.lineageabundance (lineage, lineage_abundance_id);

--------------------------------------------------------------------------------

create table Results.FunctionalUnitAbundance
  (
    functional_unit_abundance_id    numeric(12) not null,
    PROTOCOL_APP_NODE_ID  numeric(10) not null,
    unit_type varchar(60) not null,
    name varchar(60) not null,
    description varchar(254),
    species             varchar(120),
    abundance_cpm              float8,
    coverage_fraction         float8,
    MODIFICATION_DATE     date not null,
    USER_READ             numeric(1) not null,
    USER_WRITE            numeric(1) not null,
    GROUP_READ            numeric(1) not null,
    GROUP_WRITE           numeric(1) not null,
    OTHER_READ            numeric(1) not null,
    OTHER_WRITE           numeric(1) not null,
    ROW_USER_ID           numeric(12) not null,
    ROW_GROUP_ID          numeric(4) not null,
    ROW_PROJECT_ID        numeric(4) not null,
    ROW_ALG_INVOCATION_ID numeric(12) not null,
    foreign key (PROTOCOL_APP_NODE_ID) references STUDY.PROTOCOLAPPNODE,
    primary key (functional_unit_abundance_id)
  );

create sequence RESULTS.FunctionalUnitAbundance_SQ;

GRANT insert, select, update, delete ON  RESULTS.FunctionalUnitAbundance TO gus_w;
GRANT select ON RESULTS.FunctionalUnitAbundance TO gus_r;
GRANT select ON RESULTS.FunctionalUnitAbundance_sq TO gus_w;


INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     ROW_ALG_INVOCATION_ID)
SELECT NEXTVAL('CORE.TABLEINFO_SQ'), 'FunctionalUnitAbundance',
       'Standard', 'functional_unit_abundance_id',
       d.database_id, 0, 0, NULL, NULL, 1,localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (select DATABASE_ID from CORE.DATABASEINFO where name = 'Results') D
WHERE 'functionalunitabundance' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    where DATABASE_ID = D.DATABASE_ID);

CREATE INDEX fua_revix1 ON results.functionalunitabundance (protocol_app_node_id, functional_unit_abundance_id);
CREATE INDEX fua_revix2 ON results.functionalunitabundance (unit_type, name, functional_unit_abundance_id);

--------------------------------------------------------------------------------

create table Results.LineageTaxon
  (
    lineage_taxon_id    numeric(12) not null,
    lineage             varchar(254) not null,
    taxon_id                  numeric(12) not null,
    MODIFICATION_DATE     date not null,
    USER_READ             numeric(1) not null,
    USER_WRITE            numeric(1) not null,
    GROUP_READ            numeric(1) not null,
    GROUP_WRITE           numeric(1) not null,
    OTHER_READ            numeric(1) not null,
    OTHER_WRITE           numeric(1) not null,
    ROW_USER_ID           numeric(12) not null,
    ROW_GROUP_ID          numeric(4) not null,
    ROW_PROJECT_ID        numeric(4) not null,
    ROW_ALG_INVOCATION_ID numeric(12) not null,
    foreign key (taxon_id) references SRES.TAXON,
    primary key (lineage_taxon_id)
  );

GRANT insert, select, update, delete ON  RESULTS.LineageTaxon TO gus_w;
GRANT select ON RESULTS.LineageTaxon TO gus_r;

CREATE SEQUENCE RESULTS.LineageTaxon_SQ;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     ROW_ALG_INVOCATION_ID)
select NEXTVAL('CORE.TABLEINFO_SQ'), 'LineageTaxon',
       'Standard', 'lineage_taxon_id',
       d.database_id, 0, 0, NULL, NULL, 1,localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (select DATABASE_ID from CORE.DATABASEINFO where name = 'Results') D
WHERE 'lineagetaxon' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    where DATABASE_ID = D.DATABASE_ID);

-------------------------------------------------------------------------------------------
-- unique constraints in the Results schema

CREATE INDEX uqreporterintensity ON results.reporterintensity (reporter_id, protocol_app_node_id);

CREATE INDEX uqcompoundmassspec ON results.compoundmassspec (compound_id, isotopomer, protocol_app_node_id);

CREATE INDEX uqnafeaturehostresponse ON results.nafeaturehostresponse (na_feature_id, protocol_app_node_id);

CREATE INDEX uqpanlineage ON results.lineageabundance (protocol_app_node_id, lineage);

CREATE INDEX uqeditingevent ON results.editingevent (na_sequence_id, event_start, event_end, protocol_app_node_id);

CREATE INDEX uqfamilydiffresult ON results.familydiffresult (family_id, protocol_app_node_id);

CREATE INDEX uqfamilyexpression ON results.familyexpression (family_id, protocol_app_node_id);

CREATE INDEX uqgenediffresult ON results.genediffresult (gene_id, protocol_app_node_id);

CREATE INDEX uqgeneexpression ON results.geneexpression (gene_id, protocol_app_node_id);

CREATE INDEX uqgenesimilarity ON results.genesimilarity (gene1_id, gene2_id, protocol_app_node_id);

CREATE INDEX uqnafeaturediffresult ON results.nafeaturediffresult (na_feature_id, protocol_app_node_id);

CREATE INDEX uqnafeatureexpression ON results.nafeatureexpression (na_feature_id, protocol_app_node_id);

CREATE INDEX uqnafeaturephenotypecomp ON results.nafeaturephenotypecomp (na_feature_id, phenotype_composition_id, protocol_app_node_id);

CREATE INDEX uqreporterdiffresult ON results.reporterdiffresult (reporter_id, protocol_app_node_id);

CREATE INDEX uqreporterexpression ON results.reporterexpression (reporter_id, protocol_app_node_id);

CREATE INDEX uqrnadiffresult ON results.rnadiffresult (rna_id, protocol_app_node_id);

CREATE INDEX uqrnaexpression ON results.rnaexpression (rna_id, protocol_app_node_id);

CREATE INDEX uqsegmentdiffresult ON results.segmentdiffresult (na_sequence_id, segment_start, segment_end, protocol_app_node_id);

CREATE INDEX uqsegmentresult ON results.segmentresult (na_sequence_id, segment_start, segment_end, protocol_app_node_id);

CREATE INDEX uqlineage ON results.lineagetaxon (lineage);

--------------------------------------------------------------------------------
-- needed to run pivot() function on NaFeatureExpression
grant select on results.NaFeatureExpression to public;
--------------------------------------------------------------------------------

ALTER TABLE Sres.PathwayNode ADD cellular_location varchar(200);
ALTER TABLE Sres.PathwayRelationship ADD is_reversible numeric(1);

-- TODO incompatible
-- GRANT REFERENCES on sres.ontologyterm to eda;
-- GRANT REFERENCES on sres.ontologyterm to eda_ud;

-- GRANT REFERENCES on sres.ExternalDatabaseRelease to eda;
-- GRANT REFERENCES on sres.ExternalDatabaseRelease to eda_ud;
