CREATE TABLE ApiDB.AlphaFold (
  ALPHAFOLD_ID                  NUMBER(12)    NOT NULL,
  UNIPROT_ID                    VARCHAR2(15)  NOT NULL,
  FIRST_RESIDUE_INDEX           NUMBER(10),
  LAST_RESIDUE_INDEX            NUMBER(10),
  SOURCE_ID                     VARCHAR2(20)  NOT NULL,
  ALPHAFOLD_VERSION             NUMBER(5)     NOT NULL,
  MODIFICATION_DATE             DATE,
  USER_READ                     NUMBER(1),
  USER_WRITE                    NUMBER(1),
  GROUP_READ                    NUMBER(10),
  GROUP_WRITE                   NUMBER(1),
  OTHER_READ                    NUMBER(1),
  OTHER_WRITE                   NUMBER(1),
  ROW_USER_ID                   NUMBER(12),
  ROW_GROUP_ID                  NUMBER(4),
  ROW_PROJECT_ID                NUMBER(4),
  ROW_ALG_INVOCATION_ID         NUMBER(12),
  PRIMARY KEY (ALPHAFOLD_ID)
);

CREATE INDEX apidb.af_ix0 on ApiDB.AlphaFold(uniprot_id, alphafold_id) TABLESPACE indx;

CREATE SEQUENCE ApiDB.ALPHAFOLD_SQ;

GRANT SELECT ON ApiDB.AlphaFold TO gus_r;

GRANT INSERT, SELECT, UPDATE, DELETE ON ApiDB.AlphaFold TO gus_w;

GRANT SELECT ON ApiDB.AlphaFold_SQ TO gus_r;
GRANT SELECT ON ApiDB.AlphaFold_SQ TO gus_w;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable,
     modification_date, user_read, user_write, group_read, group_write,
     other_read, other_write, row_user_id, row_group_id, row_project_id,
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'AlphaFold',
       'Standard', 'ALPHAFOLD_ID',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'AlphaFold' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);

exit;
