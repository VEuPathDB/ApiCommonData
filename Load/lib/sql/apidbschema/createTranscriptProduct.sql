CREATE TABLE apidb.TranscriptProduct (
 transcript_product_id        NUMBER(12) NOT NULL,
 na_feature_id                NUMBER(12) NOT NULL,
 external_database_release_id NUMBER(12) NOT NULL,
 product                      VARCHAR(500) NOT NULL,
 is_preferred                 NUMBER(1) NOT NULL,
 publication                  VARCHAR2(20),           -- e.g. "PMID:18534909"
 evidence_code                NUMBER(10),             -- foreign key to sres.OntologyTerm 
 with_from                    VARCHAR2(500),           -- e.g. "UniProtKB:RL2A_YEAST"
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

ALTER TABLE apidb.TranscriptProduct
ADD CONSTRAINT transc_prod_pk PRIMARY KEY (transcript_product_id);

ALTER TABLE apidb.TranscriptProduct
ADD CONSTRAINT transc_prod_fk1 FOREIGN KEY (na_feature_id)
REFERENCES dots.NaFeatureImp (na_feature_id);

ALTER TABLE apidb.TranscriptProduct
ADD CONSTRAINT transc_prod_fk2 FOREIGN KEY (external_database_release_id)
REFERENCES sres.ExternalDatabaseRelease (external_database_release_id);

ALTER TABLE apidb.TranscriptProduct
ADD CONSTRAINT transc_prod_fk3 FOREIGN KEY (evidence_code)
REFERENCES sres.OntologyTerm (ontology_term_id);

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.TranscriptProduct TO gus_w;
GRANT SELECT ON apidb.TranscriptProduct TO gus_r;

CREATE INDEX apidb.transc_prod_idx ON apidb.TranscriptProduct (na_feature_id, is_preferred, product);
CREATE INDEX apidb.tfp_mod_idx ON apidb.TranscriptProduct (modification_date, transcript_product_id);
CREATE INDEX apidb.tfp_revidx ON apidb.TranscriptProduct (external_database_release_id, transcript_product_id);

------------------------------------------------------------------------------

CREATE SEQUENCE apidb.TranscriptProduct_sq;

GRANT SELECT ON apidb.TranscriptProduct_sq TO gus_r;
GRANT SELECT ON apidb.TranscriptProduct_sq TO gus_w;

------------------------------------------------------------------------------

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'TranscriptProduct',
       'Standard', 'transcript_product_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'transcriptproduct' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);


exit;
