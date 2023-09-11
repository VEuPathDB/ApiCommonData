CREATE TABLE Results.TaxonResult (
  TAXON_RESULT_ID               NUMBER(12)    NOT NULL,
  NCBI_TAX_ID                   NUMBER(10)   NOT NULL,
  VALUE                         FLOAT, 
  MODIFICATION_DATE             DATE,
  USER_READ                     NUMBER(1),
  USER_WRITE                    NUMBER(1),
  GROUP_READ                    NUMBER(10),
  GROUP_WRITE                   NUMBER(1),
  OTHER_READ                    NUMBER(1),
  OTHER_WRITE                   NUMBER(1),
  ROW_USER_ID                   NUMBER(12),
  ROW_GROUP_ID                  NUMBER(4),
  ROW_PROJECT_ID        	NUMBER(4),
  ROW_ALG_INVOCATION_ID		NUMBER(12),
  PRIMARY KEY (TAXON_RESULT_ID)
);


CREATE TABLE Results.AlgorithmResult (
  ALGORITHM_RESULT_ID           NUMBER(12)    NOT NULL,
  ALGORITHM_ID                  NUMBER(10)   NOT NULL,
  VALUE                         FLOAT, 
  MODIFICATION_DATE             DATE,
  USER_READ                     NUMBER(1),
  USER_WRITE                    NUMBER(1),
  GROUP_READ                    NUMBER(10),
  GROUP_WRITE                   NUMBER(1),
  OTHER_READ                    NUMBER(1),
  OTHER_WRITE                   NUMBER(1),
  ROW_USER_ID                   NUMBER(12),
  ROW_GROUP_ID                  NUMBER(4),
  ROW_PROJECT_ID        	NUMBER(4),
  ROW_ALG_INVOCATION_ID		NUMBER(12),
  PRIMARY KEY (TAXON_RESULT_ID)
);


CREATE SEQUENCE Results.TaxonResult_SQ;
CREATE SEQUENCE Results.AlgorithmResult_SQ;


GRANT SELECT ON Results.TaxonResult TO gus_r;
GRANT SELECT ON Results.AlgorithmResult TO gus_r;


GRANT INSERT, SELECT, UPDATE, DELETE ON Results.TaxonResult TO gus_w;
GRANT INSERT, SELECT, UPDATE, DELETE ON Results.AlgorithmResult TO gus_w;

GRANT SELECT ON Results.TaxonResult TO gus_r;
GRANT SELECT ON Results.TaxonResult tO gus_w;
GRANT SELECT ON Results.AlgorithmResult TO gus_r;
GRANT SELECT ON Results.AlgorithmResult tO gus_w;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable,
     modification_date, user_read, user_write, group_read, group_write,
     other_read, other_write, row_user_id, row_group_id, row_project_id,
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'TaxonResult',
       'Standard', 'TAXON_RESULT_ID',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'Results') d
WHERE 'TaxonResult' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable,
     modification_date, user_read, user_write, group_read, group_write,
     other_read, other_write, row_user_id, row_group_id, row_project_id,
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'AlgorithmResult',
       'Standard', 'ALGORITHM_RESULT_ID',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'Results') d
WHERE 'AlgorithmResult' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);

exit;
