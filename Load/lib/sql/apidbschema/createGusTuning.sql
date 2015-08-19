-- schema changes for GUS tables



-- not in gus4
--alter table sres.GoEvidenceCode modify (name varchar2(20));
--alter table sres.Reference modify (author varchar2(2000));
-- gus4 change
--alter table sres.DbRef modify (secondary_identifier varchar2(150));
--alter table sres.DbRef modify (lowercase_secondary_identifier varchar2(150));
--alter table dots.Est modify (accession varchar2(50));
--alter table sres.ExternalDatabase modify (name varchar2(150));
--alter table dots.NaFeatureImp modify (source_id varchar2(80));

alter table dots.rnafeatureexon add (coding_start number(12), coding_end number(12) );


-- added to XML
-- alter table sres.EnzymeClass modify (description varchar2(200));
-- alter table dots.SequencePiece add (start_position number(12), end_position number(12) );
-- alter table dots.NaFeatureImp modify (name varchar2(80));
-- alter table sres.dbref modify (secondary_identifier varchar2(200));
-- alter table dots.Library modify (stage varchar2(150));

-- indexes on GUS tables

create index dots.AaSeq_source_ix
  on dots.AaSequenceImp (lower(source_id)) tablespace INDX;

--create index dots.NaFeat_alleles_ix
--  on dots.NaFeatureImp (subclass_view, number4, number5, na_sequence_id, na_feature_id)
--  tablespace INDX;

create index dots.AaSequenceImp_string2_ix
  on dots.AaSequenceImp (string2, aa_sequence_id)
  tablespace INDX;

create index dots.nasequenceimp_string1_seq_ix
  on dots.NaSequenceImp (string1, external_database_release_id, na_sequence_id)
  tablespace INDX;

create index dots.nasequenceimp_string1_ix
  on dots.NaSequenceImp (string1, na_sequence_id)
  tablespace INDX;

-- create index dots.ExonOrder_ix
--   on dots.NaFeatureImp (subclass_view, parent_id, number3, na_feature_id)
--   tablespace INDX; 

-- create index dots.SeqvarStrain_ix
--   on dots.NaFeatureImp (subclass_view, external_database_release_id, string9, na_feature_id) -- string9 = strain
--   tablespace INDX; 

-- create index dots.FeatLocIx
--   on dots.NaLocation (na_feature_id, start_min, end_max, is_reversed)
--   tablespace INDX; 

create index dots.rfe_rnaexix
  on dots.RnaFeatureExon (rna_feature_id, exon_feature_id)
  tablespace indx;


-- for the tuning manager, which decides whether an input table has changed
-- by finding its record count and max(modification_date)
create index dots.nf_submod_ix
  on dots.NaFeatureImp (subclass_view, modification_date, na_feature_id);

create index dots.af_submod_ix
  on dots.AaFeatureImp (subclass_view, modification_date, aa_feature_id);

create index dots.ns_submod_ix
  on dots.NaSequenceImp (subclass_view, modification_date, na_sequence_id);

create index dots.as_submod_ix
  on dots.AaSequenceImp (subclass_view, modification_date, aa_sequence_id);


create index dots.aal_mod_ix on dots.aalocation (modification_date, aa_location_id);
create index dots.asmseq_mod_ix on dots.assemblysequence (modification_date, assembly_sequence_id);
create index dots.ba_mod_ix on dots.blatalignment (modification_date, blat_alignment_id);
create index dots.drnf_mod_ix on dots.dbrefaafeature (modification_date, db_ref_aa_feature_id);
create index dots.draf_mod_ix on dots.dbrefnafeature (modification_date, db_ref_na_feature_id);
create index dots.est_mod_ix on dots.est (modification_date, est_id);
create index dots.gi_mod_ix on dots.geneinstance (modification_date, gene_instance_id);
create index dots.ga_mod_ix on dots.goassociation (modification_date, go_association_id);
create index dots.gai_mod_ix on dots.goassociationinstance (modification_date, go_association_instance_id);
create index dots.gaec_mod_ix on dots.goassocinstevidcode (modification_date, go_assoc_inst_evid_code_id);
create index dots.nfc_mod_ix on dots.nafeaturecomment (modification_date, na_feature_comment_id);
create index dots.nfng_mod_ix on dots.nafeaturenagene (modification_date, na_feature_na_gene_id);
create index dots.ng_mod_ix on dots.nagene (modification_date, na_gene_id);
create index dots.nal_mod_ix on dots.nalocation (modification_date, na_location_id);
create index dots.sp_mod_ix on dots.sequencepiece (modification_date, sequence_piece_id);
create index dots.ssg_mod_ix on dots.sequencesequencegroup (modification_date, sequence_sequence_group_id);
create index dots.sim_mod_ix on dots.similarity (modification_date, similarity_id);
create index dots.simspan_mod_ix on dots.similarityspan (modification_date, similarity_span_id);

create index sres.dbref_mod_ix on sres.dbref (modification_date, db_ref_id);
--create index sres.gr_mod_ix on sres.gorelationship (modification_date, go_relationship_id);
--create index sres.gt_mod_ix on sres.goterm (modification_date, go_term_id);
create index sres.tx_mod_ix on sres.taxon (modification_date, taxon_id);
create index sres.txname_mod_ix on sres.taxonname (modification_date, taxon_name_id);


-- for OrthoMCL:
-- string1 = secondary_identifier = full_id
create index dots.lwrFullId_ix
on dots.AaSequenceImp(lower(string1), aa_sequence_id, string1)
tablespace indx;

create index dots.lwrSrcId_ix
on dots.AaSequenceImp(lower(source_id), aa_sequence_id, string1)
tablespace indx;

create index sres.lwrRefPrim_ix
on sres.DbRef(lower(primary_identifier), db_ref_id, external_database_release_id)
tablespace indx;

create index sres.lwrRefSec_ix
on sres.DbRef(lower(secondary_identifier), db_ref_id, external_database_release_id)
tablespace indx;

-- constrain NaSequence source_ids to be unique
alter table dots.NaSequenceImp
add constraint source_id_uniq
unique (source_id);

-- have Oracle create optimizer stats for the column pair (subclass_view, external_database_release_id)
select dbms_stats.create_extended_stats('DOTS', 'NAFEATUREIMP', '(SUBCLASS_VIEW, EXTERNAL_DATABASE_RELEASE_ID)') from dual;

--------------------------------------------------------------------------------
-- constrain GeneFeature source_ids to be unique
-- commented out April 2013 -- we can have duplicate source_ids as long as all but one have IS_PREDICTED set
-- create or replace package dots.GeneId_trggr_pkg
-- as
--     type geneIdList is table of varchar2(120) index by binary_integer;
--          stale    geneIdList;
--          empty    geneIdList;
--      end;
-- /
-- 
-- -- once per statement, initialize the list of GeneFeature source IDs potentially added to NaFeatureImp
-- create or replace trigger dots.geneId_setup
-- before insert or update on dots.NaFeatureImp
-- begin
--     GeneId_trggr_pkg.stale := GeneId_trggr_pkg.empty;
-- end;
-- /
-- 
-- -- once per row, if it's a GeneFeature, note the new source_id
-- create or replace trigger dots.geneId_markId
-- before insert or update on dots.NaFeatureImp
-- for each row
-- declare
--     i    number default GeneId_trggr_pkg.stale.count+1;
-- begin
--   if :new.subclass_view = 'GeneFeature' and :new.source_id is not null then
--     GeneId_trggr_pkg.stale(i) := :new.source_id;
--   end if;
-- end;
-- /
-- 
-- -- after the statement, check that none of the new source_ids are duplicated
-- create or replace trigger dots.geneId_checkDups
--    after insert or update on dots.NaFeatureImp
-- declare
--   record_count number;
-- begin
--     for i in 1 .. GeneId_trggr_pkg.stale.count loop
-- 
--         begin
--           select count(*)
--           into record_count
--           from dots.GeneFeature
--           where source_id = GeneId_trggr_pkg.stale(i);
--         end;
-- 
--         if record_count > 1 then
--           raise_application_error(-20103, 'Error:  trying to write source_id "' || GeneId_trggr_pkg.stale(i) || '" to DoTS.GeneFeature but that source_id already exists');
--         end if;
--     end loop;
-- end;
-- /

--------------------------------------------------------------------------------

-- upgrade GUS_W to support CTXSYS indexes (Oracle Text)
GRANT EXECUTE ON CTXSYS.CTX_CLS TO GUS_W;
GRANT EXECUTE ON CTXSYS.CTX_DDL TO GUS_W;
GRANT EXECUTE ON CTXSYS.CTX_DOC TO GUS_W;
GRANT EXECUTE ON CTXSYS.CTX_OUTPUT TO GUS_W;
GRANT EXECUTE ON CTXSYS.CTX_QUERY TO GUS_W;
GRANT EXECUTE ON CTXSYS.CTX_REPORT TO GUS_W;
GRANT EXECUTE ON CTXSYS.CTX_THES TO GUS_W;
GRANT EXECUTE ON CTXSYS.CTX_ULEXER TO GUS_W;
GRANT EXECUTE ON CTXSYS.DRUE TO GUS_W;
GRANT EXECUTE ON CTXSYS.CATINDEXMETHODS TO GUS_W;
GRANT CREATE INDEXTYPE to GUS_W;
GRANT CREATE CLUSTER to GUS_W;
GRANT CREATE DATABASE LINK to GUS_W;
GRANT CREATE JOB to GUS_W;
GRANT CREATE PROCEDURE to GUS_W;
GRANT CREATE SEQUENCE to GUS_W;
GRANT CREATE SESSION to GUS_W;
GRANT CREATE SYNONYM to GUS_W;
GRANT CREATE TABLE to GUS_W;
GRANT CREATE TRIGGER to GUS_W;
GRANT CREATE TYPE to GUS_W;
GRANT CREATE VIEW to GUS_W;
GRANT MANAGE SCHEDULER to GUS_W;
GRANT SELECT ANY DICTIONARY to GUS_W;
 
-- GRANTs required for CTXSYS
GRANT CONNECT, RESOURCE, CTXAPP, GUS_W to core;
GRANT CONNECT, RESOURCE, CTXAPP, GUS_W to dots;

GRANT CONNECT, RESOURCE, CTXAPP, GUS_W to study;
GRANT CONNECT, RESOURCE, CTXAPP, GUS_W to sres;

-- for v$ selects, which are needed by org.gusdb.fgputil.db.ConnectionWrapper to
-- check for uncommitted transactions before returning connections to the pool.
GRANT SELECT_CATALOG_ROLE TO GUS_R;

-- indexes to help queries against SnpFeature
-- (and some ALTER TABLE statements to make the indexes possible;
--  Oracle wants index keys no bigger than about 6K bytes)
alter table dots.NaFeatureImp
      modify (string8 varchar(1500), 
              string9 varchar(1500), 
              string12 varchar(1500), 
              string18 varchar(1500));

create index dots.SnpStrain_ix on dots.NaFeatureImp
   (subclass_view, string9, string8, number3, float2, float3, parent_id, string12, string18, na_feature_id)
   tablespace INDX;

create index dots.SnpDiff_ix on dots.NaFeatureImp
  (subclass_view, parent_id, string18, string9, number3, float2, float3, string12, na_feature_id)
  tablespace INDX;

-- indexes for orthomcl keyword and pfam searches -- only needed in OrthoMCL instance
-- CREATE INDEX dots.aasequenceimp_ind_desc ON dots.AaSequenceImp (description)
--     indextype IS ctxsys.ctxcat;
    
-- CREATE INDEX sres.dbref_ind_id2 ON sres.DbRef (secondary_identifier)
--     indextype IS ctxsys.ctxcat;

-- CREATE INDEX sres.dbref_ind_rmk ON sres.DbRef (remark)
--     indextype IS ctxsys.ctxcat;

-- create index sres.DbRefLowerId on sres.DbRef (external_database_release_id, lower(primary_identifier), db_ref_id);
-- create index sres.DbRefLowerId2 on sres.DbRef (external_database_release_id, lower(secondary_identifier), db_ref_id);

-- create index orthomcl_id_ix on dots.AaSequenceImp(subclass_view, string1, aa_sequence_id);


-- add this to prevent race condition in which we write duplicate rows
-- when plugins first run in a workflow on a brand new instance
ALTER TABLE core.algorithmimplementation
ADD CONSTRAINT alg_imp_uniq
UNIQUE (executable, cvs_revision);


-- add columns to a GUS view
-- drop first, because this view already exists from GUS install
-- (and don't drop in dropGusTuning.sql)



DROP VIEW dots.massspecfeature;
CREATE VIEW DOTS.MASSSPECFEATURE AS
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




alter table study.protocolappnode add (node_order_num number(10));

alter table results.FamilyExpression add (percentile_channel1 FLOAT(126));
alter table results.GeneExpression add (percentile_channel1 FLOAT(126));
alter table results.NaFeatureExpression add (percentile_channel1 FLOAT(126));
alter table results.ReporterExpression add (percentile_channel1 FLOAT(126));
alter table results.RnaExpression add (percentile_channel1 FLOAT(126));

alter table results.FamilyExpression add (percentile_channel2 FLOAT(126));
alter table results.GeneExpression add (percentile_channel2 FLOAT(126));
alter table results.NaFeatureExpression add (percentile_channel2 FLOAT(126));
alter table results.ReporterExpression add (percentile_channel2 FLOAT(126));
alter table results.RnaExpression add (percentile_channel2 FLOAT(126));

create table RESULTS.REPORTERINTENSITY
  (
    REPORTER_INTENSITY_ID number(12) not null,
    PROTOCOL_APP_NODE_ID   number(10) not null,
    REPORTER_ID            number(12) not null,
    value float(126),
    CONFIDENCE float(126),
    STANDARD_ERROR float(126),
    CATEGORICAL_VALUE     varchar2(100),
    MODIFICATION_DATE     date not null,
    USER_READ             number(1) not null,
    USER_WRITE            number(1) not null,
    GROUP_READ            number(1) not null,
    GROUP_WRITE           number(1) not null,
    OTHER_READ            number(1) not null,
    OTHER_WRITE           number(1) not null,
    ROW_USER_ID           number(12) not null,
    ROW_GROUP_ID          number(4) not null,
    ROW_PROJECT_ID        number(4) not null,
    ROW_ALG_INVOCATION_ID number(12) not null,
    foreign key (PROTOCOL_APP_NODE_ID) references STUDY.PROTOCOLAPPNODE,
    foreign key (REPORTER_ID) references PLATFORM.REPORTER,
    primary key (REPORTER_INTENSITY_ID)
  );


create sequence RESULTS.REPORTERINTENSITY_SQ;

GRANT insert, select, update, delete ON  RESULTS.REPORTERINTENSITY TO gus_w;
GRANT select ON RESULTS.REPORTERINTENSITY TO gus_r;
GRANT select ON RESULTS.REPORTERINTENSITY_sq TO gus_w;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     ROW_ALG_INVOCATION_ID)
select CORE.TABLEINFO_SQ.NEXTVAL, 'ReporterIntensity',
       'Standard', 'reporter_intensity_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (select DATABASE_ID from CORE.DATABASEINFO where name = 'Results') D
WHERE 'reporterintensity' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    where DATABASE_ID = D.DATABASE_ID);


--------------------------------------------------------------------------------
create table Results.CompoundMassSpec
  (
    compound_mass_spec_id number(12) not null,
    PROTOCOL_APP_NODE_ID   number(10) not null,
    compound_id            number(12) not null,
    value                  float(126),
    isotopomer            varchar2(100),
    MODIFICATION_DATE     date not null,
    USER_READ             number(1) not null,
    USER_WRITE            number(1) not null,
    GROUP_READ            number(1) not null,
    GROUP_WRITE           number(1) not null,
    OTHER_READ            number(1) not null,
    OTHER_WRITE           number(1) not null,
    ROW_USER_ID           number(12) not null,
    ROW_GROUP_ID          number(4) not null,
    ROW_PROJECT_ID        number(4) not null,
    ROW_ALG_INVOCATION_ID number(12) not null,
    foreign key (PROTOCOL_APP_NODE_ID) references STUDY.PROTOCOLAPPNODE,
    primary key (compound_mass_spec_ID)
  );


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
select CORE.TABLEINFO_SQ.NEXTVAL, 'CompoundMassSpec',
       'Standard', 'compound_mass_spec_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (select DATABASE_ID from CORE.DATABASEINFO where name = 'Results') D
WHERE 'compoundmassspec' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    where DATABASE_ID = D.DATABASE_ID);



-----------------------------------------------------------------------------

create table RESULTS.NAFeatureHostResponse
  (
    NA_FEATURE_HOST_RESPONSE_ID number(12) not null,
    PROTOCOL_APP_NODE_ID   number(10) not null,
    na_feature_ID            number(12) not null,
    value float(126),
    MODIFICATION_DATE     date not null,
    USER_READ             number(1) not null,
    USER_WRITE            number(1) not null,
    GROUP_READ            number(1) not null,
    GROUP_WRITE           number(1) not null,
    OTHER_READ            number(1) not null,
    OTHER_WRITE           number(1) not null,
    ROW_USER_ID           number(12) not null,
    ROW_GROUP_ID          number(4) not null,
    ROW_PROJECT_ID        number(4) not null,
    ROW_ALG_INVOCATION_ID number(12) not null,
    foreign key (PROTOCOL_APP_NODE_ID) references STUDY.PROTOCOLAPPNODE,
    foreign key (NA_FEATURE_ID) references DoTS.NAFeatureImp,
    primary key (NA_FEATURE_HOST_RESPONSE_ID)
  );


create sequence RESULTS.NAFEATUREHOSTRESPONSE_SQ;

GRANT insert, select, update, delete ON  RESULTS.NAFEATUREHOSTRESPONSE TO gus_w;
GRANT select ON RESULTS.NAFEATUREHOSTRESPONSE TO gus_r;
GRANT select ON RESULTS.NAFEATUREHOSTRESPONSE_sq TO gus_w;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     ROW_ALG_INVOCATION_ID)
select CORE.TABLEINFO_SQ.NEXTVAL, 'NaFeatureHostResponse',
       'Standard', 'na_feature_host_response_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (select DATABASE_ID from CORE.DATABASEINFO where name = 'Results') D
WHERE 'nafeaturehostresponse' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    where DATABASE_ID = D.DATABASE_ID);


--------------------------------------------------------------------------------



--------------------------------------------------------------------------------

alter table Sres.PathwayNode add (cellular_location varchar2(200));
alter table Sres.PathwayRelationship add (is_reversible number(1));

exit
