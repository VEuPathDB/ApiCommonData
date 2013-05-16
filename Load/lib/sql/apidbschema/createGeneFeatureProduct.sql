CREATE TABLE apidb.GeneFeatureProduct (
 gene_feature_product_id      NUMBER(12) NOT NULL,
 na_feature_id                NUMBER(12) NOT NULL,
 external_database_release_id NUMBER(12) NOT NULL,
 product                      VARCHAR(400) NOT NULL,
 is_preferred                 NUMBER(1) NOT NULL,
 modification_date            DATE NOT NULL,
 user_read                    NUMBER(1) NOT NULL,
 user_write                   NUMBER(1) NOT NULL,
 group_read                   NUMBER(1) NOT NULL,
 group_write                  NUMBER(1) NOT NULL,
 other_read                   NUMBER(1) NOT NULL,
 other_write                  NUMBER(1) NOT NULL,
 row_user_id                  NUMBER(12) NOT NULL,
 row_group_id                 NUMBER(3) NOT NULL,
 row_project_id               NUMBER(4) NOT NULL,
 row_alg_invocation_id        NUMBER(12) NOT NULL
);

ALTER TABLE apidb.GeneFeatureProduct
ADD CONSTRAINT gene_prod_pk PRIMARY KEY (gene_feature_product_id);

ALTER TABLE apidb.GeneFeatureProduct
ADD CONSTRAINT gene_prod_fk1 FOREIGN KEY (na_feature_id)
REFERENCES dots.NaFeatureImp (na_feature_id);

ALTER TABLE apidb.GeneFeatureProduct
ADD CONSTRAINT gene_prod_fk2 FOREIGN KEY (external_database_release_id)
REFERENCES sres.ExternalDatabaseRelease (external_database_release_id);

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.GeneFeatureProduct TO gus_w;
GRANT SELECT ON apidb.GeneFeatureProduct TO gus_r;

CREATE INDEX apidb.gene_prod_idx ON apidb.GeneFeatureProduct (na_feature_id, is_preferred, product);
CREATE INDEX apidb.gfp_mod_idx ON apidb.GeneFeatureProduct (modification_date, gene_feature_product_id);

------------------------------------------------------------------------------

CREATE SEQUENCE apidb.GeneFeatureProduct_sq;

GRANT SELECT ON apidb.GeneFeatureProduct_sq TO gus_r;
GRANT SELECT ON apidb.GeneFeatureProduct_sq TO gus_w;

------------------------------------------------------------------------------

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'GeneFeatureProduct',
       'Standard', 'gene_feature_product_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'genefeatureproduct' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);


exit;
