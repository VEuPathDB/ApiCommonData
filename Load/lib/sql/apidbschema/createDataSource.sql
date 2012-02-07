CREATE TABLE apidb.DataSource (
 data_source_id               NUMBER(12) NOT NULL,
 name                         VARCHAR2(120) NOT NULL,
 version                      VARCHAR2(20) NOT NULL,
 is_species_scope             NUMBER(1),
 taxon_id                     NUMBER(12),
 type                         VARCHAR2(100),
 subtype                      VARCHAR2(100),
 external_database_name       VARCHAR2(120),
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

ALTER TABLE apidb.DataSource
ADD CONSTRAINT data_source_pk PRIMARY KEY (data_source_id);

ALTER TABLE apidb.DataSource
ADD CONSTRAINT data_source_uniq
UNIQUE (name, row_project_id);

ALTER TABLE apidb.DataSource
ADD CONSTRAINT data_source_fk1 FOREIGN KEY (taxon_id)
REFERENCES sres.taxon (taxon_id);

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.DataSource TO gus_w;
GRANT SELECT ON apidb.DataSource TO gus_r;

CREATE SEQUENCE apidb.DataSource_sq;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'DataSource',
       'Standard', 'data_source_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'datasource' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);


exit;
