CREATE TABLE apidb.GeneName (
 gene_name_id                 NUMBER(12) NOT NULL,
 gene_id                      NUMBER(12) NOT NULL,
 external_database_release_id NUMBER(12) NOT NULL,
 name                         VARCHAR(60) NOT NULL,
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

ALTER TABLE apidb.GeneName
ADD CONSTRAINT gene_name_pk PRIMARY KEY (gene_name_id);

ALTER TABLE apidb.GeneName
ADD CONSTRAINT gene_name_fk1 FOREIGN KEY (gene_id)
REFERENCES dots.Gene (gene_id);

ALTER TABLE apidb.GeneName
ADD CONSTRAINT gene_name_fk2 FOREIGN KEY (external_database_release_id)
REFERENCES sres.ExternalDatabaseRelease (external_database_release_id);

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.GeneName TO gus_w;
GRANT SELECT ON apidb.GeneName TO gus_r;

CREATE INDEX apiDB.gene_name_idx ON apiDB.GeneName(gene_id, is_preferred, name);

------------------------------------------------------------------------------

CREATE SEQUENCE apidb.GeneName_sq;

GRANT SELECT ON apidb.GeneName_sq TO gus_r;
GRANT SELECT ON apidb.GeneName_sq TO gus_w;

------------------------------------------------------------------------------

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'GeneName',
       'Standard', 'gene_name_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'genename' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);


exit;
