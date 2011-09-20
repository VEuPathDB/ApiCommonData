
CREATE FUNCTION modtime() RETURNS trigger AS '
    BEGIN
        new.modification_date := current_timestamp;
        RETURN new;
    END;
' LANGUAGE 'plpgsql';


create table apidb.GeneDetail (
      SOURCE_ID character varying(100),
      PROJECT_ID character varying(50),
      FIELD_NAME VARCHAR(50),
      FIELD_TITLE VARCHAR(1000),
      ROW_COUNT NUMERIC,
      CONTENT TEXT,
      MODIFICATION_DATE TIMESTAMP
);

CREATE INDEX genedtl_idx01 ON apidb.GeneDetail(source_id, project_id, field_name) tablespace indx;
CREATE INDEX genedtl_idx02 ON apidb.GeneDetail(field_name, source_id) tablespace indx;
CREATE INDEX genedtl_idx03 ON apidb.GeneDetail(row_count, source_id) tablespace indx;

CREATE INDEX gene_text_ix on apidb.GeneDetail(content);

CREATE TRIGGER GeneDtl_md_tg
BEFORE UPDATE OR INSERT ON apidb.GeneDetail
FOR EACH ROW EXECUTE PROCEDURE
    modtime();


create table apidb.IsolateDetail (
      SOURCE_ID character varying(50),
      PROJECT_ID character varying(50),
      FIELD_NAME VARCHAR(50),
      FIELD_TITLE VARCHAR(1000),
      ROW_COUNT NUMERIC,
      CONTENT TEXT,
      MODIFICATION_DATE TIMESTAMP
);

CREATE INDEX isolatedtl_idx01 ON apidb.IsolateDetail(source_id, project_id, field_name);
CREATE INDEX isolatedtl_idx02 ON apidb.IsolateDetail(field_name, source_id);
CREATE INDEX isolatedtl_idx03 ON apidb.IsolateDetail(row_count, source_id);

CREATE INDEX isolate_text_ix on apidb.IsolateDetail(content);

CREATE TRIGGER IsolateDtl_md_tg
BEFORE UPDATE OR INSERT ON apidb.IsolateDetail
FOR EACH ROW EXECUTE PROCEDURE
    modtime();


------------------------------------------------------------------------------

create table apidb.SequenceDetail (
      SOURCE_ID character varying(50),
      PROJECT_ID character varying(50),
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
BEFORE UPDATE OR INSERT ON apidb.SequenceDetail
FOR EACH ROW EXECUTE PROCEDURE
    modtime();



------------------------------------------------------------------------------
-- GeneGff (formerly GeneTable) holds data used for the GFF download

CREATE TABLE apidb.GeneGff (
 wdk_table_id NUMERIC(10) not null,
 source_id  character varying(50),
 project_id  character varying(50),
 table_name character varying(80),
 row_count  NUMERIC(4),
 content    TEXT,
 primary key (wdk_table_id),
 modification_date TIMESTAMP
);

CREATE INDEX gtab_ix
       ON apidb.GeneGff (source_id, table_name, row_count);
CREATE INDEX gtab_name_ix
       ON apidb.GeneGff (table_name, source_id, row_count);

CREATE TRIGGER GeneGff_md_tg
before update or insert on apidb.GeneGff
FOR EACH ROW EXECUTE PROCEDURE
    modtime();


------------------------------------------------------------------------------
CREATE SEQUENCE apidb.geneGff_pkseq;


------------------------------------------------------------------------------
