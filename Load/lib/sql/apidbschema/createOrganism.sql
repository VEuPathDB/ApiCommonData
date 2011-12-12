CREATE TABLE apidb.Organism (
 organism_id                  NUMBER(12) NOT NULL,
 taxon_id                     number(12) not null,
 project_name                 VARCHAR2(20) NOT NULL,
 abbrev                       VARCHAR2(20) NOT NULL,
 abbrev_public                VARCHAR2(20) NOT NULL,
 name_for_filenames           VARCHAR2(50) NOT NULL,
 abbrev_orthomcl              VARCHAR2(20) NOT NULL,
 abbrev_strain                VARCHAR2(20) NOT NULL,
 abbrev_ref_strain            VARCHAR2(20) NOT NULL,
 is_reference_strain          NUMBER(1) NOT NULL,
 is_annotated_genome          NUMBER(1) NOT NULL,
 has_temporary_ncbi_taxon_id  NUMBER(1) NOT NULL,
 has_plastid_genome_seq       NUMBER(1) NOT NULL,
 has_mito_genome_seq          NUMBER(1) NOT NULL,
 modification_date            DATE NOT NULL,
 user_read                   NUMBER(1) NOT NULL,
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

ALTER TABLE apidb.Organism
ADD CONSTRAINT organism_pk PRIMARY KEY (organism_id);

ALTER TABLE apidb.Organism
ADD CONSTRAINT organism_uniq
UNIQUE (taxon_id, project_name);

ALTER TABLE apidb.Organism
ADD CONSTRAINT organism_fk1 FOREIGN KEY (taxon_id)
REFERENCES sres.taxon (taxon_id);

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.Organism TO gus_w;
GRANT SELECT ON apidb.Organism TO gus_r;

CREATE SEQUENCE apidb.Organism_sq;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'Organism',
       'Standard', 'organism_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'organism' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);


exit;
