create table ApiDB.PhenotypeModel (
 phenotype_model_id           NUMERIC(10) ,
 external_database_release_id NUMERIC(10) NOT NULL,
 na_feature_id                NUMERIC(10),
 source_id                    VARCHAR(50),
 name                         VARCHAR(100),
 pubmed_id                    NUMERIC(10),
 modification_type            VARCHAR(100),
 experiment_type              VARCHAR(100),
 allele                       VARCHAR(300),
 is_successful                NUMERIC(1),
 organism                     VARCHAR(200),
 has_multiple_mutations       NUMERIC(1),
 mutation_description         VARCHAR(500),
 modification_date            DATE,
 user_read                    NUMERIC(1),
 user_write                   NUMERIC(1),
 group_read                   NUMERIC(1),
 group_write                  NUMERIC(1),
 other_read                   NUMERIC(1),
 other_write                  NUMERIC(1),
 row_user_id                  NUMERIC(12),
 row_group_id                 NUMERIC(3),
 row_project_id               NUMERIC(4),
 row_alg_invocation_id        NUMERIC(12),
 FOREIGN KEY (external_database_release_id) REFERENCES sres.ExternalDatabaseRelease,
 FOREIGN KEY (na_feature_id) REFERENCES dots.NaFeatureImp,
 PRIMARY KEY (phenotype_model_id)
);

CREATE INDEX phenmod_revix0 ON apidb.PhenotypeModel (external_database_release_id, phenotype_model_id) TABLESPACE indx;
CREATE INDEX phenmod_revix1 ON apidb.PhenotypeModel (na_feature_id, phenotype_model_id) TABLESPACE indx;

CREATE SEQUENCE apidb.PhenotypeModel_sq;

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.PhenotypeModel TO gus_w;
GRANT SELECT ON apidb.PhenotypeModel TO gus_r;
GRANT SELECT ON apidb.PhenotypeModel_sq TO gus_w;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'PhenotypeModel',
       'Standard', 'phenotype_model_id',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'phenotypemodel' NOT IN (SELECT LOWER(name) FROM core.TableInfo
                               WHERE database_id = d.database_id);
 

create table ApiDB.PhenotypeResult (
 phenotype_result_id          NUMERIC(10),
 phenotype_model_id           NUMERIC(10),
 phenotype_quality_term_id    NUMERIC(10),
 phenotype_entity_term_id     NUMERIC(10),
 timing                       VARCHAR(50),
 life_cycle_stage_term_id     NUMERIC(10),
 phenotype_post_composition   TEXT,
 phenotype_comment            VARCHAR(2000),
 chebi_annotation_extension   VARCHAR(200),
 protein_annotation_extension VARCHAR(200),
 evidence_term_id             NUMERIC(10),
 modification_date            DATE,
 user_read                    NUMERIC(1),
 user_write                   NUMERIC(1),
 group_read                   NUMERIC(1),
 group_write                  NUMERIC(1),
 other_read                   NUMERIC(1),
 other_write                  NUMERIC(1),
 row_user_id                  NUMERIC(12),
 row_group_id                 NUMERIC(3),
 row_project_id               NUMERIC(4),
 row_alg_invocation_id        NUMERIC(12),
 FOREIGN KEY (phenotype_model_id) REFERENCES apidb.PhenotypeModel,
 FOREIGN KEY (phenotype_quality_term_id) REFERENCES sres.OntologyTerm,
 FOREIGN KEY (phenotype_entity_term_id) REFERENCES sres.OntologyTerm,
 FOREIGN KEY (life_cycle_stage_term_id) REFERENCES sres.OntologyTerm,
 FOREIGN KEY (evidence_term_id) REFERENCES sres.OntologyTerm,
 PRIMARY KEY (phenotype_result_id)
);

CREATE INDEX phenres_revix0 ON apidb.PhenotypeResult (evidence_term_id, phenotype_result_id) TABLESPACE indx;
CREATE INDEX phenres_revix1 ON apidb.PhenotypeResult (life_cycle_stage_term_id, phenotype_result_id) TABLESPACE indx;
CREATE INDEX phenres_revix2 ON apidb.PhenotypeResult (phenotype_entity_term_id, phenotype_result_id) TABLESPACE indx;
CREATE INDEX phenres_revix3 ON apidb.PhenotypeResult (phenotype_model_id, phenotype_result_id) TABLESPACE indx;
CREATE INDEX phenres_revix4 ON apidb.PhenotypeResult (phenotype_quality_term_id, phenotype_result_id) TABLESPACE indx;

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
SELECT NEXTVAL('core.tableinfo_sq'), 'PhenotypeResult',
       'Standard', 'phenotype_result_id',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'phenotyperesult' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);



------------------------------------------------------------------------------
create table apidb.NaFeaturePhenotypeModel
      (na_feature_phenotype_model_id NUMERIC(10) NOT NULL,
       phenotype_model_id            NUMERIC(10) NOT NULL,
       na_feature_id                 NUMERIC(10),
modification_date            DATE,
user_read                    NUMERIC(1),
user_write                   NUMERIC(1),
group_read                   NUMERIC(1),
group_write                  NUMERIC(1),
other_read                   NUMERIC(1),
other_write                  NUMERIC(1),
row_user_id                  NUMERIC(12),
row_group_id                 NUMERIC(3),
row_project_id               NUMERIC(4),
row_alg_invocation_id        NUMERIC(12),
       FOREIGN KEY (phenotype_model_id) REFERENCES apidb.phenotypemodel,
       FOREIGN KEY (na_feature_id) REFERENCES dots.NaFeatureImp,
       PRIMARY KEY (na_feature_phenotype_model_id)
      );

CREATE INDEX nfpm_revix0 ON apidb.NaFeaturePhenotypeModel (na_feature_id, na_feature_phenotype_model_id) TABLESPACE indx;
CREATE INDEX nfpm_revix1 ON apidb.NaFeaturePhenotypeModel (phenotype_model_id, na_feature_phenotype_model_id) TABLESPACE indx;

CREATE SEQUENCE apidb.NaFeaturePhenotypeModel_sq;


GRANT insert, select, update, delete ON apidb.NaFeaturePhenotypeModel TO gus_w;
GRANT select ON apidb.NaFeaturePhenotypeModel TO gus_r;
GRANT select ON apidb.NaFeaturePhenotypeModel_sq TO gus_w;


INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'NaFeaturePhenotypeModel',
       'Standard', 'na_feature_phenotype_model_id',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE lower('NaFeaturePhenotypeModel') NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

------------------------------------------------------------------------------
