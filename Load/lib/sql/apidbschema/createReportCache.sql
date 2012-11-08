create table apidb.GeneDetail (
      SOURCE_ID VARCHAR2(100 BYTE),
      PROJECT_ID VARCHAR2(50 BYTE),
      FIELD_NAME VARCHAR(50 BYTE),
      FIELD_TITLE VARCHAR(1000 BYTE),
      ROW_COUNT NUMBER,
      CONTENT CLOB,
      MODIFICATION_DATE DATE
);

CREATE INDEX apidb.genedtl_idx01 ON apidb.GeneDetail(source_id, project_id, field_name) tablespace indx;
CREATE INDEX apidb.genedtl_idx02 ON apidb.GeneDetail(field_name, source_id) tablespace indx;
CREATE INDEX apidb.genedtl_idx03 ON apidb.GeneDetail(row_count, source_id) tablespace indx;

CREATE INDEX apidb.gene_text_ix on apidb.GeneDetail(content)
indextype is ctxsys.context
parameters('DATASTORE CTXSYS.DEFAULT_DATASTORE SYNC (ON COMMIT)');

CREATE TRIGGER apidb.GeneDtl_md_tg
BEFORE UPDATE OR INSERT ON apidb.GeneDetail
FOR EACH ROW
BEGIN
  :new.modification_date := sysdate;
END;
/

GRANT insert, select, update, delete ON apidb.GeneDetail TO gus_w;
GRANT select ON apidb.GeneDetail TO gus_r;

------------------------------------------------------------------------------

create table apidb.IsolateDetail (
      SOURCE_ID VARCHAR2(50 BYTE),
      PROJECT_ID VARCHAR2(50 BYTE),
      FIELD_NAME VARCHAR(50 BYTE),
      FIELD_TITLE VARCHAR(1000 BYTE),
      ROW_COUNT NUMBER,
      CONTENT CLOB,
      MODIFICATION_DATE DATE
);

CREATE INDEX apidb.isolatedtl_idx01 ON apidb.IsolateDetail(source_id, project_id, field_name);
CREATE INDEX apidb.isolatedtl_idx02 ON apidb.IsolateDetail(field_name, source_id);
CREATE INDEX apidb.isolatedtl_idx03 ON apidb.IsolateDetail(row_count, source_id);

CREATE INDEX apidb.isolate_text_ix on apidb.IsolateDetail(content)
indextype is ctxsys.context
parameters('DATASTORE CTXSYS.DEFAULT_DATASTORE SYNC (ON COMMIT)');

CREATE TRIGGER apidb.IsolateDtl_md_tg
BEFORE UPDATE OR INSERT ON apidb.IsolateDetail
FOR EACH ROW
BEGIN
  :new.modification_date := sysdate;
END;
/

GRANT insert, select, update, delete ON apidb.IsolateDetail TO gus_w;
GRANT select ON apidb.IsolateDetail TO gus_r;

------------------------------------------------------------------------------

create table apidb.SequenceDetail (
      SOURCE_ID VARCHAR2(50 BYTE),
      PROJECT_ID VARCHAR2(50 BYTE),
      FIELD_NAME VARCHAR(50 BYTE),
      FIELD_TITLE VARCHAR(1000 BYTE),
      ROW_COUNT NUMBER,
      CONTENT CLOB,
      MODIFICATION_DATE DATE
);

CREATE INDEX apidb.sequence_text_ix on apidb.SequenceDetail(content)
indextype is ctxsys.context
parameters('DATASTORE CTXSYS.DEFAULT_DATASTORE SYNC (ON COMMIT)');

CREATE TRIGGER apidb.SeqDtl_md_tg
BEFORE UPDATE OR INSERT ON apidb.SequenceDetail
FOR EACH ROW
BEGIN
  :new.modification_date := sysdate;
END;
/

GRANT insert, select, update, delete ON apidb.SequenceDetail TO gus_w;
GRANT select ON apidb.SequenceDetail TO gus_r;

------------------------------------------------------------------------------

-- for OrthoMCL
create table apidb.GroupDetail (
      GROUP_NAME VARCHAR2(50 BYTE),
      FIELD_NAME VARCHAR(50 BYTE),
      FIELD_TITLE VARCHAR(1000 BYTE),
      ROW_COUNT NUMBER,
      CONTENT CLOB,
      MODIFICATION_DATE DATE
);

CREATE INDEX apidb.group_text_ix on apidb.GroupDetail(content)
indextype is ctxsys.context
parameters('DATASTORE CTXSYS.DEFAULT_DATASTORE SYNC (ON COMMIT)');

CREATE TRIGGER apidb.GrpDtl_md_tg
BEFORE UPDATE OR INSERT ON apidb.GroupDetail
FOR EACH ROW
BEGIN
  :new.modification_date := sysdate;
END;
/

GRANT insert, select, update, delete ON apidb.GroupDetail TO gus_w;
GRANT select ON apidb.GroupDetail TO gus_r;

------------------------------------------------------------------------------
-- GeneGff (formerly GeneTable) holds data used for the GFF download

CREATE TABLE apidb.GeneGff (
 wdk_table_id number(10) not null,
 source_id  VARCHAR2(50),
 project_id  VARCHAR2(50),
 table_name VARCHAR2(80),
 row_count  NUMBER(4),
 content    CLOB,
 primary key (wdk_table_id),
 modification_date date
);

CREATE INDEX apidb.gtab_ix
       ON apidb.GeneGff (source_id, table_name, row_count);
CREATE INDEX apidb.gtab_name_ix
       ON apidb.GeneGff (table_name, source_id, row_count);

GRANT insert, select, update, delete ON ApiDB.GeneGff TO gus_w;
GRANT select ON ApiDB.GeneGff TO gus_r;

CREATE OR REPLACE TRIGGER apidb.GeneGff_md_tg
before update or insert on apidb.GeneGff
for each row
begin
  :new.modification_date := sysdate;
end;
/

------------------------------------------------------------------------------
CREATE SEQUENCE apidb.geneGff_pkseq;

GRANT SELECT ON apidb.geneGff_pkseq TO gus_w;

------------------------------------------------------------------------------
exit;
