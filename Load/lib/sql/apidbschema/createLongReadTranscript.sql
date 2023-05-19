
CREATE TABLE ApiDB.LongReadTranscript (
  long_read_transcript_id	NUMBER(10) NOT NULL,
  gene_source_id       		varchar2(100) NOT NULL,
  transcript_source_id         	varchar2(100) NOT NULL,
  talon_gene_name             	varchar2(100) NOT NULL,
  talon_transcript_name         varchar2(100) NOT NULL,
  number_of_exon	 	NUMBER(10) NOT NULL,
  transcript_length             NUMBER(10) NOT NULL,
  gene_novelty             	varchar2(100) NOT NULL,
  transcript_novelty           	varchar2(100) NOT NULL,
  incomplete_splice_match_type  varchar2(100) NOT NULL,
  min_Start             	NUMBER(10) NOT NULL,
  max_End          		NUMBER(10) NOT NULL,
  na_seq_source_id             	varchar2(100) NOT NULL,
  external_database_release_id	NUMBER(10) NOT NULL,
  count_data			CLOB NOT NULL,
  MODIFICATION_DATE     	DATE,
  USER_READ             	NUMBER(1),
  USER_WRITE            	NUMBER(1),
  GROUP_READ            	NUMBER(1),
  GROUP_WRITE           	NUMBER(1),
  OTHER_READ            	NUMBER(1),
  OTHER_WRITE           	NUMBER(1),
  ROW_USER_ID           	NUMBER(12),
  ROW_GROUP_ID          	NUMBER(3),
  ROW_PROJECT_ID        	NUMBER(4),
  ROW_ALG_INVOCATION_ID 	NUMBER(12),
  PRIMARY KEY (long_read_transcript_id),
  FOREIGN KEY (external_database_release_id) REFERENCES SRes.ExternalDatabaseRelease (external_database_release_id)
);

--create index apidb.long_read_transcript_ix
--  on apidb.LongReadTranscript (gene_source_id, transcript_source_id, min_Start, max_End, na_seq_source_id) tablespace indx;

CREATE SEQUENCE ApiDB.LongReadTranscript_sq;

GRANT insert, select, update, delete ON ApiDB.LongReadTranscript TO gus_w;
GRANT select ON ApiDB.LongReadTranscript TO gus_r;
GRANT select ON ApiDB.LongReadTranscript_sq TO gus_w;

INSERT INTO core.TableInfo
  (table_id, name, table_type, primary_key_column, database_id,
    is_versioned, is_view, view_on_table_id, superclass_table_id, is_updatable,
    modification_date, user_read, user_write, group_read, group_write,
    other_read, other_write, row_user_id, row_group_id, row_project_id,
    row_alg_invocation_id)
  SELECT core.tableinfo_sq.nextval, 'LongReadTranscript', 'Standard', 'long_read_transcript_id',
    d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1, p.project_id, 0
  FROM dual,
       (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
       (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
  WHERE 'LongReadTranscript' NOT IN (SELECT name FROM core.TableInfo
  WHERE database_id = d.database_id);

------------------------------------------------------------------------------

exit;
