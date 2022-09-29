create table ApiDB.PhenotypeMutants (
 phenotype_mutants_id           NUMERIC(10),
 na_feature_id                  NUMERIC(10),
 protocol_app_node_id           NUMERIC(10) NOT NULL,
 fgsc                           VARCHAR(50),
 pubmed                         NUMERIC(10),
 gene_classification            VARCHAR(50),
 gene_name                      VARCHAR(50),
 mating_type                    VARCHAR(10),
 basal_hyphae_growth_rate       NUMERIC(10,4),
 aerial_hyphae_height           NUMERIC(10,4),
 conidia_number                 VARCHAR(50),
 conidia_morphology             VARCHAR(50),
 protoperithecia_number         VARCHAR(50),
 protoperithecial_morphology    VARCHAR(50),
 perithecia_number	        VARCHAR(50),
 perithecia_morphology          VARCHAR(50),
 ascospore_number	        VARCHAR(50),
 ascospore_morphology           VARCHAR(50),
 modification_date              DATE,
 user_read                    	NUMERIC(1),
 user_write                   	NUMERIC(1),
 group_read                  	NUMERIC(1),
 group_write                  	NUMERIC(1),
 other_read                   	NUMERIC(1),
 other_write                  	NUMERIC(1),
 row_user_id                  	NUMERIC(12),
 row_group_id                 	NUMERIC(3),
 row_project_id               	NUMERIC(4),
 row_alg_invocation_id        	NUMERIC(12),
 FOREIGN KEY (na_feature_id)    REFERENCES dots.NaFeatureImp,
 FOREIGN KEY (protocol_app_node_id) REFERENCES Study.ProtocolAppNode,
 PRIMARY KEY (phenotype_mutants_id)
);

create index phenmutants_1
  on apidb.phenotypemutants (na_feature_id, phenotype_mutants_id) tablespace indx;

CREATE SEQUENCE apidb.PhenotypeMutants_sq;

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.Phenotypemutants TO gus_w;
GRANT SELECT ON apidb.Phenotypemutants TO gus_r;
GRANT SELECT ON apidb.Phenotypemutants_sq TO gus_w;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'PhenotypeMutants',
       'Standard', 'phenotype_mutants_id',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM
     (SELECT MIN(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'phenotypemutants' NOT IN (SELECT LOWER(name) FROM core.TableInfo
                               WHERE database_id = d.database_id);
