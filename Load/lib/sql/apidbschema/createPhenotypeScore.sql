create table ApiDB.PhenotypeScore (
 phenotype_score_id           NUMBER(10) ,
 na_feature_id                NUMBER(10),
 protocol_app_node_id         NUMBER(10) NOT NULL,
 score                        NUMBER(10),
 score_type                   VARCHAR(100),
 FOREIGN KEY (na_feature_id) REFERENCES dots.NaFeatureImp,
 FOREIGN KEY (protocol_app_node_id) REFERENCES Study.ProtocolAppNode,
 PRIMARY KEY (phenotype_score_id)
);

create index apidb.phenscore_1
  on apidb.phenotypescore (na_feature_id, phenotype_score_id) tablespace indx;

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
SELECT core.tableinfo_sq.nextval, 'PhenotypeScore',
       'Standard', 'phenotype_score_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MIN(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'phenotypescore' NOT IN (SELECT LOWER(name) FROM core.TableInfo
                               WHERE database_id = d.database_id);

exit;
