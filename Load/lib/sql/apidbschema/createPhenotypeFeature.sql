
CREATE TABLE apidb.PhenotypeFeature (
 phenotype_feature_id       NUMBER(10),
 external_database_release_id NUMBER(10) NOT NULL,
 na_feature_id               NUMBER(10) NOT NULL,
 suc_of_gen_mod                  varchar(10),
 reference_pubmed               NUMBER(10),
 phenotype_asexual                     varchar(100),
 phenotype_gametocyte                     varchar(100),
 phenotype_ookinete                     varchar(100),
 phenotype_oocyst                     varchar(100),
 phenotype_sporozoite                     varchar(100),
 phenotype_liverstage                     varchar(100),
 phenotype_remarks                     varchar(500),
 mod_type                     varchar(100),
 MODIFICATION_DATE            DATE,
 USER_READ                    NUMBER(1),
 USER_WRITE                   NUMBER(1),
 GROUP_READ                   NUMBER(1),
 GROUP_WRITE                  NUMBER(1),
 OTHER_READ                   NUMBER(1),
 OTHER_WRITE                  NUMBER(1),
 ROW_USER_ID                  NUMBER(12),
 ROW_GROUP_ID                 NUMBER(3),
 ROW_PROJECT_ID               NUMBER(4),
 ROW_ALG_INVOCATION_ID        NUMBER(12),
 FOREIGN KEY (external_database_release_id) REFERENCES SRes.ExternalDatabaseRelease,
 PRIMARY KEY (phenotype_feature_id)
);

CREATE SEQUENCE apidb.PhenotypeFeature_sq;

GRANT insert, select, update, delete ON apidb.PhenotypeFeature TO gus_w;
GRANT select ON apidb.PhenotypeFeature TO gus_r;
GRANT select ON apidb.PhenotypeFeature_sq TO gus_w;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'PhenotypeFeature',
       'Standard', 'phenotype_feature_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'phenotypefeature' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

------------------------------------------------------------------------------
exit;
