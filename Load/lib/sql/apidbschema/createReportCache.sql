create table apidb.GeneDetail (
      SOURCE_ID VARCHAR2(100 BYTE),
      PROJECT_ID VARCHAR2(50 BYTE),
      FIELD_NAME VARCHAR(50 BYTE),
      FIELD_TITLE VARCHAR(1000 BYTE),
      ROW_COUNT NUMBER,
      CONTENT CLOB,
      MODIFICATION_DATE DATE
);

CREATE UNIQUE INDEX apidb.genedtl_idx01 ON apidb.GeneDetail(source_id, project_id, field_name) tablespace indx;
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

create table apidb.OrthomclSequenceDetail (
      FULL_ID VARCHAR2(50 BYTE),
      FIELD_NAME VARCHAR(50 BYTE),
      FIELD_TITLE VARCHAR(1000 BYTE),
      ROW_COUNT NUMBER,
      CONTENT CLOB,
      MODIFICATION_DATE DATE
);

CREATE INDEX apidb.sequence_text_ix on apidb.OrthomclSequenceDetail(content)
indextype is ctxsys.context
parameters('DATASTORE CTXSYS.DEFAULT_DATASTORE SYNC (ON COMMIT)');

CREATE TRIGGER apidb.OrtSeqDtl_md_tg
BEFORE UPDATE OR INSERT ON apidb.OrthomclSequenceDetail
FOR EACH ROW
BEGIN
  :new.modification_date := sysdate;
END;
/

GRANT insert, select, update, delete ON apidb.OrthomclSequenceDetail TO gus_w;
GRANT select ON apidb.OrthomclSequenceDetail TO gus_r;

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
 modification_date date,
 USER_READ             NUMBER(1),
 USER_WRITE            NUMBER(1),
 GROUP_READ            NUMBER(1),
 GROUP_WRITE           NUMBER(1),
 OTHER_READ            NUMBER(1),
 OTHER_WRITE           NUMBER(1),
 ROW_USER_ID           NUMBER(12),
 ROW_GROUP_ID          NUMBER(3),
 ROW_PROJECT_ID        NUMBER(4),
 ROW_ALG_INVOCATION_ID NUMBER(12),
 primary key (wdk_table_id)
);

CREATE SEQUENCE ApiDB.GeneGff_sq;

CREATE INDEX apidb.ggff_ix
       ON apidb.GeneGff (source_id, table_name, row_count);
CREATE INDEX apidb.ggff_name_ix
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

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'GeneGff',
       'Standard', 'WDK_TABLE_ID',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'genegff' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    where database_id = d.database_id);

------------------------------------------------------------------------------
CREATE SEQUENCE apidb.geneGff_pkseq;

GRANT SELECT ON apidb.geneGff_pkseq TO gus_w;

------------------------------------------------------------------------------

create table apidb.CompoundDetail (
      SOURCE_ID VARCHAR2(50 BYTE),
      PROJECT_ID VARCHAR2(50 BYTE),
      FIELD_NAME VARCHAR(50 BYTE),
      FIELD_TITLE VARCHAR(1000 BYTE),
      ROW_COUNT NUMBER,
      CONTENT CLOB,
      MODIFICATION_DATE DATE
);

CREATE INDEX apidb.compounddtl_idx01 ON apidb.CompoundDetail(source_id, project_id, field_name);
CREATE INDEX apidb.compounddtl_idx02 ON apidb.CompoundDetail(field_name, source_id);
CREATE INDEX apidb.compounddtl_idx03 ON apidb.CompoundDetail(row_count, source_id);

CREATE INDEX apidb.compound_text_ix on apidb.CompoundDetail(content)
indextype is ctxsys.context
parameters('DATASTORE CTXSYS.DEFAULT_DATASTORE SYNC (ON COMMIT)');

CREATE TRIGGER apidb.CompoundDtl_md_tg
BEFORE UPDATE OR INSERT ON apidb.CompoundDetail
FOR EACH ROW
BEGIN
  :new.modification_date := sysdate;
END;
/

GRANT insert, select, update, delete ON apidb.CompoundDetail TO gus_w;
GRANT select ON apidb.CompoundDetail TO gus_r;

------------------------------------------------------------------------------



exit;
