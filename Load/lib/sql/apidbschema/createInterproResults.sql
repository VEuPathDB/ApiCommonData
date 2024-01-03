CREATE TABLE ApiDB.InterproResults (
  INTERPRO_RESULTS_ID           NUMBER(10) NOT NULL,
  TRANSCRIPT_SOURCE_ID	        VARCHAR2(80),
  PROTEIN_SOURCE_ID		VARCHAR2(60) NOT NULL,
  GENE_SOURCE_ID		VARCHAR2(80),
  NCBI_TAX_ID                   NUMBER(10) NOT NULL,
  INTERPRO_DB_NAME		VARCHAR2(150) NOT NULL,
  INTERPRO_PRIMARY_ID	        VARCHAR2(100),
  INTERPRO_SECONDARY_ID	        VARCHAR2(200),
  INTERPRO_DESC		        VARCHAR2(1600),
  INTERPRO_START_MIN	        NUMBER(12),
  INTERPRO_END_MIN	        NUMBER(12),
  INTERPRO_E_VALUE	        VARCHAR2(9),
  INTERPRO_FAMILY_ID            VARCHAR2(50),
  MODIFICATION_DATE             DATE,
  USER_READ                     NUMBER(1),
  USER_WRITE                    NUMBER(1),
  GROUP_READ                    NUMBER(1),
  GROUP_WRITE                   NUMBER(1),
  OTHER_READ                    NUMBER(1),
  OTHER_WRITE                   NUMBER(1),
  ROW_USER_ID                   NUMBER(12),
  ROW_GROUP_ID                  NUMBER(3),
  ROW_PROJECT_ID                NUMBER(4),
  ROW_ALG_INVOCATION_ID         NUMBER(12),
  PRIMARY KEY (INTERPRO_RESULTS_ID)
);

CREATE SEQUENCE ApiDB.InterproResults_sq;

GRANT insert, select, update, delete ON ApiDB.InterproResults TO gus_w;
GRANT select ON ApiDB.InterproResults TO gus_r;
GRANT select ON ApiDB.InterproResults_sq TO gus_w;

INSERT INTO core.TableInfo
  (table_id, name, table_type, primary_key_column, database_id, 
    is_versioned, is_view, view_on_table_id, superclass_table_id, is_updatable, 
    modification_date, user_read, user_write, group_read, group_write, 
    other_read, other_write, row_user_id, row_group_id, row_project_id,
    row_alg_invocation_id)
  SELECT core.tableinfo_sq.nextval, 'InterproResults', 'Standard', 'interpro_results_id',
    d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1, p.project_id, 0
  FROM dual,
       (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
       (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
  WHERE 'InterproResults' NOT IN (SELECT name FROM core.TableInfo
  WHERE database_id = d.database_id); 


exit;
