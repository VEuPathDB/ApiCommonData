CREATE TABLE apidb.GeneFeatureName (
 gene_feature_name_id         NUMERIC(12) NOT NULL,
 na_feature_id                NUMERIC(12) NOT NULL,
 external_database_release_id NUMERIC(12) NOT NULL,
 name                         VARCHAR(60) NOT NULL,
 is_preferred                 NUMERIC(1) NOT NULL,
 modification_date            DATE NOT NULL,
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

ALTER TABLE apidb.GeneFeatureName
ADD CONSTRAINT gene_feature_name_pk PRIMARY KEY (gene_feature_name_id);

ALTER TABLE apidb.GeneFeatureName
ADD CONSTRAINT gene_feature_name_fk1 FOREIGN KEY (na_feature_id)
REFERENCES dots.NaFeatureImp (na_feature_id);

ALTER TABLE apidb.GeneFeatureName
ADD CONSTRAINT gene_feature_name_fk2 FOREIGN KEY (external_database_release_id)
REFERENCES sres.ExternalDatabaseRelease (external_database_release_id);

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.GeneFeatureName TO gus_w;
GRANT SELECT ON apidb.GeneFeatureName TO gus_r;

CREATE INDEX gene_feature_name_idx ON apiDB.GeneFeatureName(na_feature_id, is_preferred, name) tablespace indx;

CREATE INDEX gfn_revfk_idx
   ON apiDB.GeneFeatureName(external_database_release_id, gene_feature_name_id) tablespace indx;

------------------------------------------------------------------------------

CREATE SEQUENCE apidb.GeneFeatureName_sq;

GRANT SELECT ON apidb.GeneFeatureName_sq TO gus_r;
GRANT SELECT ON apidb.GeneFeatureName_sq TO gus_w;

------------------------------------------------------------------------------

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'GeneFeatureName',
       'Standard', 'gene_feature_name_id',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'genefeaturename' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);
