create table apidb.GoSubset(
go_subset_id NUMERIC(10) NOT NULL,
go_subset_term VARCHAR(500) NOT NULL,
ontology_term_id NUMERIC(12)  NOT NULL,
external_database_release_id NUMERIC(12) NOT NULL,
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
 row_alg_invocation_id        NUMERIC(12) NOT NULL,
    foreign key (ontology_term_id) REFERENCES sres.ontologyterm,
primary key (go_subset_id)
);

ALTER TABLE apidb.GoSubset ADD CONSTRAINT gsub_fk
      FOREIGN KEY (EXTERNAL_DATABASE_RELEASE_ID) REFERENCES sres.ExternalDatabaseRelease (EXTERNAL_DATABASE_RELEASE_ID);

CREATE INDEX gosub_revix0 ON apidb.GoSubset (external_database_release_id, go_subset_id) TABLESPACE indx;
CREATE INDEX gosub_revix1 ON apidb.GoSubset (ontology_term_id, go_subset_id) TABLESPACE indx;

CREATE SEQUENCE apidb.GoSubset_sq;


GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.GoSubset TO gus_w;
GRANT SELECT ON apidb.GoSubset TO gus_r;
GRANT SELECT ON apidb.GoSubset_sq TO gus_w;


INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable,
     modification_date, user_read, user_write, group_read, group_write,
     other_read, other_write, row_user_id, row_group_id, row_project_id,
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'),'GoSubset',
       'Standard', 'go_subset_id',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'gosubset' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);
