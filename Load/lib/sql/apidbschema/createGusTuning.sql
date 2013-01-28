-- indexes on GUS tables

create index dots.AaSeq_source_ix
  on dots.AaSequenceImp (lower(source_id)) tablespace INDX;

create index dots.NaFeat_alleles_ix
  on dots.NaFeatureImp (subclass_view, number4, number5, na_sequence_id, na_feature_id)
  tablespace INDX;

create index dots.AaSequenceImp_string2_ix
  on dots.AaSequenceImp (string2, aa_sequence_id)
  tablespace INDX;

create index dots.nasequenceimp_string1_seq_ix
  on dots.NaSequenceImp (string1, external_database_release_id, na_sequence_id)
  tablespace INDX;

create index dots.nasequenceimp_string1_ix
  on dots.NaSequenceImp (string1, na_sequence_id)
  tablespace INDX;

create index dots.ExonOrder_ix
  on dots.NaFeatureImp (subclass_view, parent_id, number3, na_feature_id)
  tablespace INDX; 

create index dots.SeqvarStrain_ix
  on dots.NaFeatureImp (subclass_view, external_database_release_id, string9, na_feature_id)
  tablespace INDX; 

-- constrain NaSequence source_ids to be unique
alter table dots.NaSequenceImp
add constraint source_id_uniq
unique (source_id);

--------------------------------------------------------------------------------
-- constrain GeneFeature source_ids to be unique

create or replace package dots.GeneId_trggr_pkg
as
    type geneIdList is table of varchar2(120) index by binary_integer;
         stale    geneIdList;
         empty    geneIdList;
     end;
/

-- once per statement, initialize the list of GeneFeature source IDs potentially added to NaFeatureImp
create or replace trigger dots.geneId_setup
before insert or update on dots.NaFeatureImp
begin
    GeneId_trggr_pkg.stale := GeneId_trggr_pkg.empty;
end;
/

-- once per row, if it's a GeneFeature, note the new source_id
create or replace trigger dots.geneId_markId
before insert or update on dots.NaFeatureImp
for each row
declare
    i    number default GeneId_trggr_pkg.stale.count+1;
begin
  if :new.subclass_view = 'GeneFeature' and :new.source_id is not null then
    GeneId_trggr_pkg.stale(i) := :new.source_id;
  end if;
end;
/

-- after the statement, check that none of the new source_ids are duplicated
create or replace trigger dots.geneId_checkDups
   after insert or update on dots.NaFeatureImp
declare
  record_count number;
begin
    for i in 1 .. GeneId_trggr_pkg.stale.count loop

        begin
          select count(*)
          into record_count
          from dots.GeneFeature
          where source_id = GeneId_trggr_pkg.stale(i);
        end;

        if record_count > 1 then
          raise_application_error(-20103, 'Error:  trying to write source_id "' || GeneId_trggr_pkg.stale(i) || '" to DoTS.GeneFeature but that source_id already exists');
        end if;
    end loop;
end;
/

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
GRANT CONNECT, RESOURCE, CTXAPP, GUS_W to rad;
GRANT CONNECT, RESOURCE, CTXAPP, GUS_W to study;
GRANT CONNECT, RESOURCE, CTXAPP, GUS_W to sres;
GRANT CONNECT, RESOURCE, CTXAPP, GUS_W to tess;
GRANT CONNECT, RESOURCE, CTXAPP, GUS_W to prot;


-- schema changes for GUS tables

alter table dots.NaFeatureImp modify (source_id varchar2(80));

alter table sres.EnzymeClass modify (description varchar2(200));

alter table sres.GoEvidenceCode modify (name varchar2(20));

alter table sres.DbRef modify (secondary_identifier varchar2(150));
alter table sres.DbRef modify (lowercase_secondary_identifier varchar2(150));

alter table dots.SequencePiece add (start_position number(12), end_position number(12) );

alter table dots.NaFeatureImp modify (name varchar2(80));

alter table dots.Est modify (accession varchar2(50));

alter table sres.ExternalDatabase modify (name varchar2(150));

alter table sres.Reference modify (author varchar2(2000));

alter table sres.dbref modify (secondary_identifier varchar2(200));

-- indexes to help queries against SnpFeature
-- (and some ALTER TABLE statements to make the indexes possible;
--  Oracle wants index keys no bigger than about 6K bytes)
alter table dots.NaFeatureImp
      modify (string8 varchar(1500), 
              string9 varchar(1500), 
              string12 varchar(1500), 
              string18 varchar(1500));

create index SnpStrain_ix on dots.NaFeatureImp
   (subclass_view, string9, string8, number3, float2, float3, parent_id, string12, string18, na_feature_id);

create index SnpDiff_ix on dots.NaFeatureImp
  (subclass_view, parent_id, string18, string9, number3, float2, float3, string12, na_feature_id);

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
DROP VIEW rad.DifferentialExpression;
CREATE VIEW rad.DifferentialExpression AS
SELECT
   analysis_result_id,
   subclass_view,
   analysis_id,
   table_id,
   row_id,
   float1 as fold_change,
   float2 as confidence,
   float3 as pvalue_mant,
   number1 as pvalue_exp,
   modification_date,
   user_read,
   user_write,
   group_read,
   group_write,
   other_read,
   other_write,
   row_user_id,
   row_group_id,
   row_project_id,
   row_alg_invocation_id
FROM RAD.AnalysisResultImp
WHERE subclass_view = 'DifferentialExpression'
WITH CHECK OPTION;

GRANT SELECT ON rad.DifferentialExpression TO gus_r;
GRANT INSERT, UPDATE, DELETE ON rad.DifferentialExpression TO gus_w;


exit
