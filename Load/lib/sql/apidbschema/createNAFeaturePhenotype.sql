create table ApiDB.NAFeaturePhenotype (
 na_feature_phenotype_id        NUMBER(10) ,
 na_feature_id                  NUMBER(10),
 protocol_app_node_id           NUMBER(10) NOT NULL,
 property                       VARCHAR2(400) NOT NULL,
 property_id                    NUMBER(10),
 value                          VARCHAR2(2000), 
 value_id                       NUMBER(10),
 value_clob                     CLOB,
 modification_date              DATE,
 user_read                      NUMBER(1),
 user_write                     NUMBER(1),
 group_read                     NUMBER(1),
 group_write                    NUMBER(1),
 other_read                     NUMBER(1),
 other_write                    NUMBER(1),
 row_user_id                    NUMBER(12),
 row_group_id                   NUMBER(3),
 row_project_id                 NUMBER(4),
 row_alg_invocation_id          NUMBER(12),
 FOREIGN KEY (na_feature_id) REFERENCES dots.NaFeatureImp,
 FOREIGN KEY (protocol_app_node_id) REFERENCES Study.ProtocolAppNode,
 FOREIGN KEY (property_id) REFERENCES sres.OntologyTerm,
 PRIMARY KEY (na_feature_phenotype_id)
);

create index apidb.nfphen_1
  on apidb.NaFeaturePhenotype (na_feature_id, na_feature_phenotype_id) tablespace indx;
create index apidb.nfphen_2
  on apidb.NaFeaturePhenotype (protocol_app_node_id, na_feature_phenotype_id) tablespace indx;
create index apidb.nfphen_3
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
SELECT core.tableinfo_sq.nextval, 'NAFeaturePhenotype',
       'Standard', 'na_feature_phenotype_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MIN(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'nafeaturephenotype' NOT IN (SELECT LOWER(name) FROM core.TableInfo
                               WHERE database_id = d.database_id);

exit;
