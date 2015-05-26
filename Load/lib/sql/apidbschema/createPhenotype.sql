create table ApiDB.PhenotypeModel (
 phenotype_model_id                       number(10) ,
 external_database_release_id      NUMBER(10) NOT NULL,
 na_feature_id                   NUMBER(10),
 source_id                                             varchar(50),
 name                                            varchar(100),
 pubmed_id                                        number(10),
 modification_type                            varchar(100),
 is_successful                                  number(1),
 organism                                          varchar(200),
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
 FOREIGN KEY (na_feature_id) REFERENCES dots.nafeatureimp,
 PRIMARY KEY (phenotype_model_id)
);

CREATE SEQUENCE apidb.PhenotypeModel_sq;

GRANT insert, select, update, delete ON apidb.PhenotypeModel TO gus_w;
GRANT select ON apidb.PhenotypeModel TO gus_r;
GRANT select ON apidb.PhenotypeModel_sq TO gus_w;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'PhenotypeModel',
       'Standard', 'phenotype_model_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'phenotypemodel' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

 

create table ApiDB.PhenotypeResult (
 phenotype_result_id                  number(10),
 phenotype_model_id                   NUMBER(10),
 external_database_release_id      NUMBER(10) NOT NULL,
 phenotype_quality_term_id                   NUMBER(10),
 phenotype_entity_term_id                   NUMBER(10),
 timing           varchar2(50),
 life_cycle_stage_term_id                   NUMBER(10),
 life_cycle_stage           varchar2(250),
 phenotype_post_composition           varchar2(2000),
 evidence_term_id                    NUMBER(10),
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
 FOREIGN KEY (phenotype_model_id) REFERENCES apidb.phenotypemodel,
 FOREIGN KEY (external_database_release_id) REFERENCES SRes.ExternalDatabaseRelease,
 FOREIGN KEY (phenotype_quality_term_id) REFERENCES sres.ontologyterm,
 FOREIGN KEY (phenotype_entity_term_id) REFERENCES sres.ontologyterm,
 FOREIGN KEY (life_cycle_stage_term_id) REFERENCES sres.ontologyterm,
 FOREIGN KEY (evidence_term_id) REFERENCES sres.ontologyterm,
 PRIMARY KEY (phenotype_result_id)
);

CREATE SEQUENCE apidb.PhenotypeResult_sq;

GRANT insert, select, update, delete ON apidb.PhenotypeResult TO gus_w;
GRANT select ON apidb.PhenotypeResult TO gus_r;
GRANT select ON apidb.PhenotypeResult_sq TO gus_w;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'PhenotypeResult',
       'Standard', 'phenotype_result_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'phenotyperesult' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);


------------------------------------------------------------------------------
exit;
