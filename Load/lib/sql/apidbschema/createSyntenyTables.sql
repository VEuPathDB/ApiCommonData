
------------------------------------------------------------------------------

CREATE TABLE ApiDB.Synteny (
 synteny_id  NUMBER(10),
 external_database_release_id NUMBER(10),
 a_na_sequence_id  NUMBER(10),	
 b_na_sequence_id  NUMBER(10),	
 a_start NUMBER(8),
 a_end NUMBER(8),
 b_start NUMBER(8),
 b_end NUMBER(8),
 is_reversed NUMBER(3),
 MODIFICATION_DATE     DATE,
 USER_READ             NUMBER(1),
 USER_WRITE            NUMBER(1),
 GROUP_READ            NUMBER(1),
 GROUP_WRITE           NUMBER(1),
 OTHER_READ            NUMBER(1),
 OTHER_WRITE           NUMBER(1),
 ROW_USER_ID           NUMBER(12),
 ROW_GROUP_ID          NUMBER(3),
 ROW_PROJECT_ID        NUMBER(4),
 ROW_ALG_INVOCATION_ID NUMBER(12),
 FOREIGN KEY (a_na_sequence_id) REFERENCES DoTS.NaSequenceImp (na_sequence_id),
 FOREIGN KEY (b_na_sequence_id) REFERENCES DoTS.NaSequenceImp (na_sequence_id),
 FOREIGN KEY (external_database_release_id) REFERENCES SRes.ExternalDatabaseRelease (external_database_release_id),
 PRIMARY KEY (synteny_id)
);

CREATE INDEX apidb.synteny_revix1
ON apidb.Synteny (b_na_sequence_id, synteny_id)
TABLESPACE INDX;

CREATE INDEX apidb.synteny_revix2
ON apidb.Synteny (external_database_release_id, synteny_id)
TABLESPACE INDX;

CREATE INDEX apidb.syn_mod_ix
ON apidb.Synteny (modification_date, synteny_id)
TABLESPACE INDX;

CREATE SEQUENCE ApiDB.Synteny_sq;

GRANT insert, select, update, delete ON ApiDB.Synteny TO gus_w;
GRANT select ON ApiDB.Synteny TO gus_r;
GRANT select ON ApiDB.Synteny_sq TO gus_w;

CREATE INDEX apidb.syn_ix
ON apidb.Synteny(a_na_sequence_id, a_start, a_end, external_database_release_id)
TABLESPACE INDX;

CREATE INDEX apidb.syn_loc_ix
ON apidb.Synteny(a_na_sequence_id, b_na_sequence_id, a_start, a_end, b_start, b_end)
TABLESPACE INDX;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'Synteny',
       'Standard', 'synteny_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'Synteny' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);

------------------------------------------------------------------------------

CREATE TABLE ApiDB.SyntenicGene (
 syntenic_gene_id            NUMBER(10),
 synteny_id                  NUMBER(10),
 na_sequence_id              number(10),
 start_min                   number,
 end_max                     number,
 is_reversed                 number(1),
 tstarts                     VARCHAR2(4000),
 blocksizes                  VARCHAR2(1200),
 syn_na_feature_id          number(10),
 syn_organism_abbrev         varchar2(40),
 modification_date           DATE,
 user_read                   NUMBER(1),
 user_write                  NUMBER(1),
 group_read                  NUMBER(1),
 group_write                 NUMBER(1),
 other_read                  NUMBER(1),
 other_write                 NUMBER(1),
 row_user_id                 NUMBER(12),
 row_group_id                NUMBER(3),
 row_project_id              NUMBER(4),
 row_alg_invocation_id       NUMBER(12),
 FOREIGN KEY (synteny_id) REFERENCES apidb.Synteny (synteny_id),
 FOREIGN KEY (syn_na_feature_id) REFERENCES dots.nafeatureimp (na_feature_id),
 FOREIGN KEY (na_sequence_id) REFERENCES dots.nasequenceimp (na_sequence_id),
 PRIMARY KEY (syntenic_gene_id)
);


CREATE SEQUENCE ApiDB.SyntenicGene_sq;

GRANT insert, select, update, delete ON ApiDB.SyntenicGene TO gus_w;
GRANT select ON ApiDB.SyntenicGene TO gus_r;
GRANT select ON ApiDB.SyntenicGene_sq TO gus_w;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'SyntenicGene',
       'Standard', 'syntenic_gene_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE LOWER(name) = 'apidb') d
WHERE 'SyntenicGene' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);

 CREATE INDEX apidb.SyntGene_f_ix
        ON apidb.SyntenicGene (na_sequence_id, start_min, end_max, synteny_id, syn_na_feature_id, syn_organism_abbrev)
 TABLESPACE INDX;


------------------------------------------------------------------------------


CREATE TABLE ApiDB.SyntenicScale (
 syntenic_scale_id            NUMBER(10),
 synteny_id                  NUMBER(10),
 na_sequence_id              number(10),
 start_min                   number,
 end_max                     number,
 scale                       number,
 ref_length                  number,
 syn_length                  number,
 syn_organism_abbrev         varchar2(40),
 modification_date           DATE,
 user_read                   NUMBER(1),
 user_write                  NUMBER(1),
 group_read                  NUMBER(1),
 group_write                 NUMBER(1),
 other_read                  NUMBER(1),
 other_write                 NUMBER(1),
 row_user_id                 NUMBER(12),
 row_group_id                NUMBER(3),
 row_project_id              NUMBER(4),
 row_alg_invocation_id       NUMBER(12),
 FOREIGN KEY (synteny_id) REFERENCES apidb.Synteny (synteny_id),
 FOREIGN KEY (na_sequence_id) REFERENCES dots.nasequenceimp (na_sequence_id),
 PRIMARY KEY (syntenic_scale_id)
);


CREATE SEQUENCE ApiDB.SyntenicScale_sq;

GRANT insert, select, update, delete ON ApiDB.SyntenicScale TO gus_w;
GRANT select ON ApiDB.SyntenicScale TO gus_r;
GRANT select ON ApiDB.SyntenicScale_sq TO gus_w;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'SyntenicScale',
       'Standard', 'syntenic_scale_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE LOWER(name) = 'apidb') d
WHERE 'SyntenicScale' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);

 CREATE INDEX apidb.SyntScale_f_ix
        ON apidb.SyntenicScale (na_sequence_id, start_min, end_max, synteny_id, syn_organism_abbrev)
 TABLESPACE INDX;

exit;
