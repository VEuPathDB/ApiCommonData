CREATE TABLE apidb.GeneFeatureProduct (
 gene_feature_product_id      NUMERIC(12) NOT NULL,
 na_feature_id                NUMERIC(12) NOT NULL,
 external_database_release_id NUMERIC(12) NOT NULL,
 product                      VARCHAR(400) NOT NULL,
 is_preferred                 NUMERIC(1) NOT NULL,
 modification_date            timestamp NOT NULL,
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

ALTER TABLE apidb.GeneFeatureProduct
ADD CONSTRAINT gene_prod_pk PRIMARY KEY (gene_feature_product_id);

ALTER TABLE apidb.GeneFeatureProduct
ADD CONSTRAINT gene_prod_fk1 FOREIGN KEY (na_feature_id)
REFERENCES dots.NaFeatureImp (na_feature_id);

ALTER TABLE apidb.GeneFeatureProduct
ADD CONSTRAINT gene_prod_fk2 FOREIGN KEY (external_database_release_id)
REFERENCES sres.ExternalDatabaseRelease (external_database_release_id);

CREATE INDEX gene_prod_idx ON apiDB.GeneFeatureProduct(na_feature_id, is_preferred, product);
CREATE INDEX apidb.gfp_mod_idx ON apidb.GeneFeatureProduct (modification_date, gene_feature_product_id);

------------------------------------------------------------------------------

CREATE SEQUENCE apidb.GeneFeatureProduct_sq;

------------------------------------------------------------------------------

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT nextval('core.tableinfo_sq'), 'GeneFeatureProduct',
       'Standard', 'gene_feature_product_id',
       (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb'), 0, 0, NULL, NULL, 
       1,current_timestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo), 0
WHERE lower('GeneFeatureProduct') NOT IN (SELECT lower(name) FROM core.TableInfo
        WHERE database_id = (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb'));

