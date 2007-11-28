CREATE TABLE apidb.OrthologGroup (
 ortholog_group_id            NUMBER(12) NOT NULL,
 subclass_view                VARCHAR2(30) NOT NULL,
 name                         VARCHAR2(500),
 description                  VARCHAR2(2000),
 number_of_members            NUMBER(12) NOT NULL,
 avg_percent_identity         FLOAT,
 avg_percent_match            FLOAT,
 avg_evalue_mant              FLOAT,
 avg_evalue_exp               NUMBER,
 avg_connectivity             FLOAT(126),
 number_of_match_pairs        NUMBER,
 aa_seq_group_experiment_id   NUMBER(12),
 external_database_release_id NUMBER(10) NOT NULL,
 mulple_sequence_alignment    CLOB,
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

ALTER TABLE apidb.OrthologGroup
ADD CONSTRAINT og_pk PRIMARY KEY (ortholog_group_id);

ALTER TABLE apidb.OrthologGroup
ADD CONSTRAINT og_fk1 FOREIGN KEY (external_database_release_id)
REFERENCES sres.ExternalDatabaseRelease;

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.OrthologGroup TO gus_w;
GRANT SELECT ON apidb.OrthologGroup TO gus_r;

------------------------------------------------------------------------------

CREATE SEQUENCE apidb.OrthologGroup_sq;

GRANT SELECT ON apidb.OrthologGroup_sq TO gus_r;
GRANT SELECT ON apidb.OrthologGroup_sq TO gus_w;

------------------------------------------------------------------------------

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'OrthologGroup',
       'Standard', 'ORTHOLOG_GROUP_ID',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'orthologgroup' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    where database_id = d.database_id);

------------------------------------------------------------------------------
CREATE TABLE apidb.OrthologGroupAaSequence (
 ortholog_group_aa_sequence_id NUMBER(12) NOT NULL,
 aa_sequence_id                NUMBER(12) NOT NULL,
 ortholog_group_id             NUMBER(12) NOT NULL,
 connectivity                  FLOAT(126),
 modification_date             DATE NOT NULL,
 user_read                     NUMBER(1) NOT NULL,
 user_write                    NUMBER(1) NOT NULL,
 group_read                    NUMBER(1) NOT NULL,
 group_write                   NUMBER(1) NOT NULL,
 other_read                    NUMBER(1) NOT NULL,
 other_write                   NUMBER(1) NOT NULL,
 row_user_id                   NUMBER(12) NOT NULL,
 row_group_id                  NUMBER(3) NOT NULL,
 row_project_id                NUMBER(4) NOT NULL,
 row_alg_invocation_id         NUMBER(12) NOT NULL
);

ALTER TABLE apidb.OrthologGroupAaSequence
ADD CONSTRAINT ogas_pk PRIMARY KEY (ortholog_group_aa_sequence_id);

ALTER TABLE apidb.OrthologGroupAaSequence
ADD CONSTRAINT ogas_fk1 FOREIGN KEY (aa_sequence_id)
REFERENCES dots.AASequenceImp (aa_sequence_id);

ALTER TABLE apidb.OrthologGroupAaSequence
ADD CONSTRAINT ogas_fk2 FOREIGN KEY (ortholog_group_id)
REFERENCES apidb.OrthologGroup (ortholog_group_id);

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.OrthologGroupAaSequence TO gus_w;
GRANT SELECT ON apidb.OrthologGroupAaSequence TO gus_r;

------------------------------------------------------------------------------

CREATE SEQUENCE apidb.OrthologGroupAaSequence_sq;

GRANT SELECT ON apidb.OrthologGroupAaSequence_sq TO gus_r;
GRANT SELECT ON apidb.OrthologGroupAaSequence_sq TO gus_w;

------------------------------------------------------------------------------

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'OrthologGroupAaSequence',
       'Standard', 'ORTHOLOG_GROUP_AA_SEQUENCE_ID',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'orthologgroupaasequence' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    where database_id = d.database_id);

exit;
