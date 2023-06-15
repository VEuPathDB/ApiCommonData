create table apidb.GeneDetail (
      SOURCE_ID VARCHAR(100),
      PROJECT_ID VARCHAR(50),
      FIELD_NAME VARCHAR(50),
      FIELD_TITLE VARCHAR(1000),
      ROW_COUNT NUMERIC,
      CONTENT TEXT,
      MODIFICATION_DATE TIMESTAMP
);

CREATE UNIQUE INDEX genedtl_idx01 ON apidb.GeneDetail(source_id, project_id, field_name) tablespace indx;
CREATE INDEX genedtl_idx02 ON apidb.GeneDetail(field_name, source_id) tablespace indx;
CREATE INDEX genedtl_idx03 ON apidb.GeneDetail(row_count, source_id) tablespace indx;

-- TODO
-- CREATE INDEX gene_text_ix on apidb.GeneDetail(content)
-- indextype is ctxsys.context
-- parameters('DATASTORE CTXSYS.DEFAULT_DATASTORE SYNC (ON COMMIT)');

-- TODO consider moving this into a more generic file if used elsewhere
CREATE OR REPLACE FUNCTION apidb.trigger_fct_update_modification_date() RETURNS trigger AS $BODY$
BEGIN
    NEW.modification_date := LOCALTIMESTAMP;
    RETURN NEW;
END
$BODY$
    LANGUAGE 'plpgsql';

CREATE TRIGGER genedtl_md_tg
    BEFORE UPDATE OR INSERT ON apidb.GeneDetail FOR EACH ROW
EXECUTE FUNCTION apidb.trigger_fct_update_modification_date();


GRANT insert, select, update, delete ON apidb.GeneDetail TO gus_w;
GRANT select ON apidb.GeneDetail TO gus_r;


------------------------------------------------------------------------------

create table apidb.IsolateDetail (
      SOURCE_ID VARCHAR(50),
      PROJECT_ID VARCHAR(50),
      FIELD_NAME VARCHAR(50),
      FIELD_TITLE VARCHAR(1000),
      ROW_COUNT numeric,
      CONTENT text,
      MODIFICATION_DATE TIMESTAMP
);

CREATE INDEX isolatedtl_idx01 ON apidb.IsolateDetail(source_id, project_id, field_name);
CREATE INDEX isolatedtl_idx02 ON apidb.IsolateDetail(field_name, source_id);
CREATE INDEX isolatedtl_idx03 ON apidb.IsolateDetail(row_count, source_id);

-- TODO
-- CREATE INDEX apidb.isolate_text_ix on apidb.IsolateDetail(content)
-- indextype is ctxsys.context
-- parameters('DATASTORE CTXSYS.DEFAULT_DATASTORE SYNC (ON COMMIT)');


CREATE TRIGGER IsolateDtl_md_tg
    BEFORE UPDATE OR INSERT ON apidb.IsolateDetail FOR EACH ROW
EXECUTE FUNCTION apidb.trigger_fct_update_modification_date();

GRANT insert, select, update, delete ON apidb.IsolateDetail TO gus_w;
GRANT select ON apidb.IsolateDetail TO gus_r;

------------------------------------------------------------------------------

create table apidb.SequenceDetail (
      SOURCE_ID VARCHAR(50),
      PROJECT_ID VARCHAR(50),
      FIELD_NAME VARCHAR(50),
      FIELD_TITLE VARCHAR(1000),
      ROW_COUNT NUMERIC,
      CONTENT TEXT,
      MODIFICATION_DATE TIMESTAMP
);

CREATE INDEX sequencedtl_idx01 ON apidb.SequenceDetail(source_id, project_id, field_name);
CREATE INDEX sequencedtl_idx02 ON apidb.SequenceDetail(field_name, source_id);
CREATE INDEX sequencedtl_idx03 ON apidb.SequenceDetail(row_count, source_id);

CREATE TRIGGER SeqDtl_md_tg
    BEFORE UPDATE OR INSERT ON apidb.SequenceDetail FOR EACH ROW
EXECUTE FUNCTION apidb.trigger_fct_update_modification_date();


GRANT insert, select, update, delete ON apidb.SequenceDetail TO gus_w;
GRANT select ON apidb.SequenceDetail TO gus_r;

------------------------------------------------------------------------------

create table apidb.OrthomclSequenceDetail (
      FULL_ID VARCHAR(50),
      FIELD_NAME VARCHAR(50),
      FIELD_TITLE VARCHAR(1000),
      ROW_COUNT numeric,
      CONTENT text,
      MODIFICATION_DATE TIMESTAMP
);

-- TODO
-- CREATE INDEX apidb.sequence_text_ix on apidb.OrthomclSequenceDetail(content)
-- indextype is ctxsys.context
-- parameters('DATASTORE CTXSYS.DEFAULT_DATASTORE SYNC (ON COMMIT)');


CREATE TRIGGER OrtSeqDtl_md_tg
    BEFORE UPDATE OR INSERT ON apidb.OrthomclSequenceDetail FOR EACH ROW
EXECUTE FUNCTION apidb.trigger_fct_update_modification_date();

GRANT insert, select, update, delete ON apidb.OrthomclSequenceDetail TO gus_w;
GRANT select ON apidb.OrthomclSequenceDetail TO gus_r;

------------------------------------------------------------------------------

-- for OrthoMCL
create table apidb.GroupDetail (
      GROUP_NAME VARCHAR(50),
      FIELD_NAME VARCHAR(50),
      FIELD_TITLE VARCHAR(1000),
      ROW_COUNT numeric,
      CONTENT text,
      MODIFICATION_DATE TIMESTAMP
);

-- TODO
-- CREATE INDEX apidb.group_text_ix on apidb.GroupDetail(content)
-- indextype is ctxsys.context
-- parameters('DATASTORE CTXSYS.DEFAULT_DATASTORE SYNC (ON COMMIT)');

CREATE TRIGGER GrpDtl_md_tg
    BEFORE UPDATE OR INSERT ON apidb.GroupDetail FOR EACH ROW
EXECUTE FUNCTION apidb.trigger_fct_update_modification_date();

GRANT insert, select, update, delete ON apidb.GroupDetail TO gus_w;
GRANT select ON apidb.GroupDetail TO gus_r;

------------------------------------------------------------------------------
-- GeneGff (formerly GeneTable) holds data used for the GFF download

CREATE TABLE apidb.GeneGff (
 wdk_table_id numeric(10) not null,
 source_id  VARCHAR(50),
 project_id  VARCHAR(50),
 table_name VARCHAR(80),
 row_count  numeric(4),
 content    text,
 modification_date TIMESTAMP,
 USER_READ             numeric(1),
 USER_WRITE            numeric(1),
 GROUP_READ            numeric(1),
 GROUP_WRITE           numeric(1),
 OTHER_READ            numeric(1),
 OTHER_WRITE           numeric(1),
 ROW_USER_ID           numeric(12),
 ROW_GROUP_ID          numeric(3),
 ROW_PROJECT_ID        numeric(4),
 ROW_ALG_INVOCATION_ID numeric(12),
 primary key (wdk_table_id)
);

CREATE SEQUENCE ApiDB.GeneGff_sq;

CREATE INDEX ggff_ix ON apidb.GeneGff (source_id, table_name, row_count);
CREATE INDEX ggff_name_ix ON apidb.GeneGff (table_name, source_id, row_count);

GRANT insert, select, update, delete ON ApiDB.GeneGff TO gus_w;
GRANT select ON ApiDB.GeneGff TO gus_r;

CREATE TRIGGER genegff_md_tg
    BEFORE UPDATE OR INSERT ON apidb.GeneGff FOR EACH ROW
EXECUTE FUNCTION apidb.trigger_fct_update_modification_date();

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'GeneGff',
       'Standard', 'WDK_TABLE_ID',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'genegff' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    where database_id = d.database_id);

------------------------------------------------------------------------------
CREATE SEQUENCE apidb.geneGff_pkseq;

GRANT SELECT ON apidb.geneGff_pkseq TO gus_w;

------------------------------------------------------------------------------

create table apidb.CompoundDetail (
      SOURCE_ID VARCHAR(50),
      PROJECT_ID VARCHAR(50),
      FIELD_NAME VARCHAR(50),
      FIELD_TITLE VARCHAR(1000),
      ROW_COUNT numeric,
      CONTENT text,
      MODIFICATION_DATE TIMESTAMP
);

CREATE INDEX compounddtl_idx01 ON apidb.CompoundDetail(source_id, project_id, field_name);
CREATE INDEX compounddtl_idx02 ON apidb.CompoundDetail(field_name, source_id);
CREATE INDEX compounddtl_idx03 ON apidb.CompoundDetail(row_count, source_id);

-- TODO
-- CREATE INDEX apidb.compound_text_ix on apidb.CompoundDetail(content)
-- indextype is ctxsys.context
-- parameters('DATASTORE CTXSYS.DEFAULT_DATASTORE SYNC (ON COMMIT)');


CREATE TRIGGER compounddtl_md_tg
    BEFORE UPDATE OR INSERT ON apidb.CompoundDetail FOR EACH ROW
EXECUTE FUNCTION apidb.trigger_fct_update_modification_date();

GRANT insert, select, update, delete ON apidb.CompoundDetail TO gus_w;
GRANT select ON apidb.CompoundDetail TO gus_r;

------------------------------------------------------------------------------
