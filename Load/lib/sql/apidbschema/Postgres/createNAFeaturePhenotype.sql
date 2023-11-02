create table ApiDB.NAFeaturePhenotype (
 na_feature_phenotype_id        NUMERIC(10) ,
 na_feature_id                  NUMERIC(10),
 protocol_app_node_id           NUMERIC(10) NOT NULL,
 property                       VARCHAR(400) NOT NULL,
 property_id                    NUMERIC(10),
 value                          VARCHAR(2000), 
 value_id                       NUMERIC(10),
 value_clob                     TEXT,
 modification_date              TIMESTAMP,
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
 FOREIGN KEY (property_id) REFERENCES sres.OntologyTerm,
 PRIMARY KEY (na_feature_phenotype_id)
);

create index nfphen_1
  on apidb.NaFeaturePhenotype (na_feature_id, na_feature_phenotype_id) tablespace indx;
create index nfphen_2
  on apidb.NaFeaturePhenotype (protocol_app_node_id, na_feature_phenotype_id) tablespace indx;
create index nfphen_3
  on apidb.NaFeaturePhenotype (property_id, na_feature_phenotype_id) tablespace indx;

CREATE SEQUENCE apidb.NAFeaturePhenotype_sq;

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.NAFeaturePhenotype TO gus_w;
GRANT SELECT ON apidb.NAFeaturePhenotype TO gus_r;
GRANT SELECT ON apidb.NAFeaturePhenotype_sq TO gus_w;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'NAFeaturePhenotype',
       'Standard', 'na_feature_phenotype_id',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM 
     (SELECT MIN(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'nafeaturephenotype' NOT IN (SELECT LOWER(name) FROM core.TableInfo
                               WHERE database_id = d.database_id);
