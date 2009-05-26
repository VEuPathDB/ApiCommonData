create table apidb.GeneDetail (
      SOURCE_ID VARCHAR2(50 BYTE),
      PROJECT_ID VARCHAR2(50 BYTE),
      FIELD_NAME VARCHAR(50 BYTE),
      FIELD_TITLE VARCHAR(1000 BYTE),
      ROW_COUNT NUMBER,
      CONTENT CLOB
);

CREATE INDEX apidb.genedtl_idx01 ON apidb.GeneDetail(source_id, project_id, field_name);
CREATE INDEX apidb.genedtl_idx02 ON apidb.GeneDetail(field_name, source_id);
CREATE INDEX apidb.genedtl_idx03 ON apidb.GeneDetail(row_count, source_id);

CREATE INDEX apidb.gene_text_ix on apidb.GeneDetail(content)
indextype is ctxsys.context
parameters('DATASTORE CTXSYS.DEFAULT_DATASTORE SYNC (ON COMMIT)');

GRANT insert, select, update, delete ON apidb.GeneDetail TO gus_w;
GRANT select ON apidb.GeneDetail TO gus_r;

------------------------------------------------------------------------------

create table apidb.IsolateDetail (
      SOURCE_ID VARCHAR2(50 BYTE),
      PROJECT_ID VARCHAR2(50 BYTE),
      FIELD_NAME VARCHAR(50 BYTE),
      FIELD_TITLE VARCHAR(1000 BYTE),
      ROW_COUNT NUMBER,
      CONTENT CLOB
);

CREATE INDEX apidb.isolatedtl_idx01 ON apidb.IsolateDetail(source_id, project_id, field_name);
CREATE INDEX apidb.isolatedtl_idx02 ON apidb.IsolateDetail(field_name, source_id);
CREATE INDEX apidb.isolatedtl_idx03 ON apidb.IsolateDetail(row_count, source_id);

CREATE INDEX apidb.isolate_text_ix on apidb.IsolateDetail(content)
indextype is ctxsys.context
parameters('DATASTORE CTXSYS.DEFAULT_DATASTORE SYNC (ON COMMIT)');

GRANT insert, select, update, delete ON apidb.IsolateDetail TO gus_w;
GRANT select ON apidb.IsolateDetail TO gus_r;

------------------------------------------------------------------------------

create table apidb.SequenceDetail (
      SOURCE_ID VARCHAR2(50 BYTE),
      PROJECT_ID VARCHAR2(50 BYTE),
      FIELD_NAME VARCHAR(50 BYTE),
      FIELD_TITLE VARCHAR(1000 BYTE),
      ROW_COUNT NUMBER,
      CONTENT CLOB
);

CREATE INDEX apidb.sequencedtl_idx01 ON apidb.SequenceDetail(source_id, project_id, field_name);
CREATE INDEX apidb.sequencedtl_idx02 ON apidb.SequenceDetail(field_name, source_id);
CREATE INDEX apidb.sequencedtl_idx03 ON apidb.SequenceDetail(row_count, source_id);

GRANT insert, select, update, delete ON apidb.SequenceDetail TO gus_w;
GRANT select ON apidb.SequenceDetail TO gus_r;

------------------------------------------------------------------------------
exit;
