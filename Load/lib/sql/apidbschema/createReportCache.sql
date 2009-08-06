create table apidb.GeneDetail (
      SOURCE_ID VARCHAR2(50 BYTE),
      PROJECT_ID VARCHAR2(50 BYTE),
      FIELD_NAME VARCHAR(50 BYTE),
      FIELD_TITLE VARCHAR(1000 BYTE),
      ROW_COUNT NUMBER,
      CONTENT CLOB,
      MODIFICATION_DATE DATE
);

CREATE INDEX apidb.genedtl_idx01 ON apidb.GeneDetail(source_id, project_id, field_name);
CREATE INDEX apidb.genedtl_idx02 ON apidb.GeneDetail(field_name, source_id);
CREATE INDEX apidb.genedtl_idx03 ON apidb.GeneDetail(row_count, source_id);

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

CREATE INDEX apidb.sequencedtl_idx01 ON apidb.SequenceDetail(source_id, project_id, field_name);
CREATE INDEX apidb.sequencedtl_idx02 ON apidb.SequenceDetail(field_name, source_id);
CREATE INDEX apidb.sequencedtl_idx03 ON apidb.SequenceDetail(row_count, source_id);

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
-- for now, include the old style as well.

CREATE TABLE apidb.GeneTable (
 wdk_table_id number(10) not null,
 source_id  VARCHAR2(50),
 project_id  VARCHAR2(50),
 table_name VARCHAR2(80),
 row_count  NUMBER(4),
 content    CLOB,
 primary key (wdk_table_id)
);

CREATE INDEX apidb.gtab_ix
       ON apidb.GeneTable (source_id, table_name, row_count);
CREATE INDEX apidb.gtab_name_ix
       ON apidb.GeneTable (table_name, source_id, row_count);

GRANT insert, select, update, delete ON ApiDB.GeneTable TO gus_w;
GRANT select ON ApiDB.GeneTable TO gus_r;

------------------------------------------------------------------------------
CREATE TABLE apidb.wdkIsolateTable (
 wdk_table_id number(10) not null,
 source_id  VARCHAR2(50),
 project_id  VARCHAR2(50),
 table_name VARCHAR2(80),
 row_count  NUMBER(4),
 content    CLOB,
 primary key (wdk_table_id)
);

CREATE INDEX apidb.itab_ix
       ON apidb.WdkIsolateTable (source_id, table_name, row_count);
CREATE INDEX apidb.itab_name_ix
       ON apidb.WdkIsolateTable (table_name, source_id, row_count);

GRANT insert, select, update, delete ON ApiDB.WdkIsolateTable TO gus_w;
GRANT select ON ApiDB.WdkIsolateTable TO gus_r;

------------------------------------------------------------------------------
CREATE SEQUENCE apidb.wdkTable_pkseq;

------------------------------------------------------------------------------
exit;
