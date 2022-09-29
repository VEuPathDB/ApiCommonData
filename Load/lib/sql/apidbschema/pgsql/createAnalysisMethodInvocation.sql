CREATE TABLE apidb.AnalysisMethodInvocation (
 analysis_method_invocation_id NUMERIC(12) NOT NULL,
 name                       VARCHAR(200) NOT NULL,
 version                    VARCHAR(30),
 parameters                 VARCHAR(200),
 modification_date            date NOT NULL,
 user_read                    NUMERIC(1) NOT NULL,
 user_write                   NUMERIC(1) NOT NULL,
 group_read                   NUMERIC(1) NOT NULL,
 group_write                  NUMERIC(1) NOT NULL,
 other_read                   NUMERIC(1) NOT NULL,
 other_write                  NUMERIC(1) NOT NULL,
 row_user_id                  NUMERIC(12) NOT NULL,
 row_group_id                 NUMERIC(3) NOT NULL,
 row_project_id               NUMERIC(4) NOT NULL,
 row_alg_invocation_id        NUMERIC(12) NOT NULL
);

ALTER TABLE apidb.AnalysisMethodInvocation
ADD CONSTRAINT anal_method_inv_pk PRIMARY KEY (analysis_method_invocation_id);

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.AnalysisMethodInvocation TO gus_w;
GRANT SELECT ON apidb.AnalysisMethodInvocation TO gus_r;

CREATE INDEX analysis_method_name_idx ON apiDB.AnalysisMethodInvocation(name);

------------------------------------------------------------------------------

CREATE SEQUENCE apidb.AnalysisMethodInvocation_sq;

GRANT SELECT ON apidb.AnalysisMethodInvocation_sq TO gus_r;
GRANT SELECT ON apidb.AnalysisMethodInvocation_sq TO gus_w;

------------------------------------------------------------------------------

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'AnalysisMethodInvocation',
       'Standard', 'analysis_method_invocation_id',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'analysismethodinvocation' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

