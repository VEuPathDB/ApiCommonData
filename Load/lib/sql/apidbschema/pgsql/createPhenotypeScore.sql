create table ApiDB.PhenotypeScore (
 phenotype_score_id           NUMERIC(10) ,
 na_feature_id                NUMERIC(10),
 protocol_app_node_id         NUMERIC(10) NOT NULL,
 score                        NUMERIC(10,4),
 score_type                   VARCHAR(100),
 modification_date              DATE,
 user_read                      NUMERIC(1),
 user_write                     NUMERIC(1),
 group_read                     NUMERIC(1),
 group_write                    NUMERIC(1),
 other_read                     NUMERIC(1),
 other_write                    NUMERIC(1),
 row_user_id                    NUMERIC(12),
 row_group_id                   NUMERIC(3),
 row_project_id                 NUMERIC(4),
 row_alg_invocation_id          NUMERIC(12),
 FOREIGN KEY (na_feature_id) REFERENCES dots.NaFeatureImp,
 FOREIGN KEY (protocol_app_node_id) REFERENCES Study.ProtocolAppNode,
 PRIMARY KEY (phenotype_score_id)
);

create index phenscore_1
  on apidb.PhenotypeScore (na_feature_id, phenotype_score_id) tablespace indx;
create index phenscore_2
  on apidb.PhenotypeScore (protocol_app_node_id, phenotype_score_id) tablespace indx;

CREATE SEQUENCE apidb.PhenotypeScore_sq;

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.Phenotypescore TO gus_w;
GRANT SELECT ON apidb.Phenotypescore TO gus_r;
GRANT SELECT ON apidb.Phenotypescore_sq TO gus_w;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'PhenotypeScore',
       'Standard', 'phenotype_score_id',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM
     (SELECT MIN(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'phenotypescore' NOT IN (SELECT LOWER(name) FROM core.TableInfo
                               WHERE database_id = d.database_id);
