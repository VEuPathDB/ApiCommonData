CREATE TABLE apidb.AASequenceUniprot (
 aa_sequence_uniprot_id  NUMBER(12) NOT NULL,
 aa_sequence_id          NUMBER(10) NOT NULL,
 uniprot_accession       VARCHAR2(20) NOT NULL,
 modification_date       DATE NOT NULL,
 user_read               NUMBER(1) NOT NULL,
 user_write              NUMBER(1) NOT NULL,
 group_read              NUMBER(1) NOT NULL,
 group_write             NUMBER(1) NOT NULL,
 other_read              NUMBER(1) NOT NULL,
 other_write             NUMBER(1) NOT NULL,
 row_user_id             NUMBER(12) NOT NULL,
 row_group_id            NUMBER(3) NOT NULL,
 row_project_id          NUMBER(4) NOT NULL,
 row_alg_invocation_id   NUMBER(12) NOT NULL,
 PRIMARY KEY (aa_sequence_uniprot_id)
);

ALTER TABLE apidb.AASequenceUniprot
ADD CONSTRAINT as_fk1 FOREIGN KEY (aa_sequence_id)
REFERENCES dots.AaSequenceImp (aa_sequence_id)

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.AASequenceUniprot TO gus_w;
GRANT SELECT ON apidb.AASequenceUniprot TO gus_r;

------------------------------------------------------------------------------

CREATE SEQUENCE apidb.AASequenceUniprot_sq;

GRANT SELECT ON apidb.AASequenceUniprot_sq TO gus_r;
GRANT SELECT ON apidb.AASequenceUniprot_sq TO gus_w;

------------------------------------------------------------------------------

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'AASequenceUniprot',
       'Standard', 'AA_SEQUENCE_UNIPROT_ID',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'aasequenceuniprot' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    where database_id = d.database_id);

------------------------------------------------------------------------------

CREATE TABLE apidb.UniprotEnzymeClass (
 uniprot_ec_id          NUMBER(12) NOT NULL,
 uniprot_accession      VARCHAR2(20) NOT NULL,
 enzyme_class_id        NUMBER(12) NOT NULL,
 modification_date      DATE NOT NULL,
 user_read              NUMBER(1) NOT NULL,
 user_write             NUMBER(1) NOT NULL,
 group_read             NUMBER(1) NOT NULL,
 group_write            NUMBER(1) NOT NULL,
 other_read             NUMBER(1) NOT NULL,
 other_write            NUMBER(1) NOT NULL,
 row_user_id            NUMBER(12) NOT NULL,
 row_group_id           NUMBER(3) NOT NULL,
 row_project_id         NUMBER(4) NOT NULL,
 row_alg_invocation_id  NUMBER(12) NOT NULL,
 PRIMARY KEY (uniprot_ec_id)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.UniprotEnzymeClass TO gus_w;
GRANT SELECT ON apidb.UniprotEnzymeClass TO gus_r;

ALTER TABLE apidb.UniprotEnzymeClass
ADD CONSTRAINT ue_fk1 FOREIGN KEY (enzyme_class_id)
REFERENCES sres.EnzymeClass (enzyme_class_id);

------------------------------------------------------------------------------

CREATE SEQUENCE apidb.UniprotEnzymeClass_sq;

GRANT SELECT ON apidb.UniprotEnzymeClass_sq TO gus_r;
GRANT SELECT ON apidb.UniprotEnzymeClass_sq TO gus_w;

------------------------------------------------------------------------------

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'UniprotEnzymeClass',
       'Standard', 'UNIPROT_EC_ID',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'uniprotenzymeclass' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    where database_id = d.database_id);


exit;


