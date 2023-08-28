
------------------------------------------------------------------------------

CREATE TABLE ApiDB.Synteny (
 synteny_id  NUMERIC(10),
 external_database_release_id NUMERIC(10),
 a_na_sequence_id  NUMERIC(10),
 b_na_sequence_id  NUMERIC(10),
 a_start NUMERIC(12),
 a_end NUMERIC(12),
 b_start NUMERIC(12),
 b_end NUMERIC(12),
 is_reversed NUMERIC(3),
 MODIFICATION_DATE     TIMESTAMP,
 USER_READ             NUMERIC(1),
 USER_WRITE            NUMERIC(1),
 GROUP_READ            NUMERIC(1),
 GROUP_WRITE           NUMERIC(1),
 OTHER_READ            NUMERIC(1),
 OTHER_WRITE           NUMERIC(1),
 ROW_USER_ID           NUMERIC(12),
 ROW_GROUP_ID          NUMERIC(3),
 ROW_PROJECT_ID        NUMERIC(4),
 ROW_ALG_INVOCATION_ID NUMERIC(12),
 FOREIGN KEY (a_na_sequence_id) REFERENCES DoTS.NaSequenceImp (na_sequence_id),
 FOREIGN KEY (b_na_sequence_id) REFERENCES DoTS.NaSequenceImp (na_sequence_id),
 FOREIGN KEY (external_database_release_id) REFERENCES SRes.ExternalDatabaseRelease (external_database_release_id),
 PRIMARY KEY (synteny_id)
);

CREATE INDEX synteny_revix1
ON apidb.Synteny (b_na_sequence_id, synteny_id)
TABLESPACE INDX;

CREATE INDEX synteny_revix2
ON apidb.Synteny (external_database_release_id, synteny_id)
TABLESPACE INDX;

CREATE INDEX syn_mod_ix
ON apidb.Synteny (modification_date, synteny_id)
TABLESPACE INDX;

CREATE SEQUENCE ApiDB.Synteny_sq;

GRANT insert, select, update, delete ON ApiDB.Synteny TO gus_w;
GRANT select ON ApiDB.Synteny TO gus_r;
GRANT select ON ApiDB.Synteny_sq TO gus_w;

CREATE INDEX syn_ix
ON apidb.Synteny(a_na_sequence_id, a_start, a_end, external_database_release_id)
TABLESPACE INDX;

CREATE INDEX syn_loc_ix
ON apidb.Synteny(a_na_sequence_id, b_na_sequence_id, a_start, a_end, b_start, b_end)
TABLESPACE INDX;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'Synteny',
       'Standard', 'synteny_id',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM 
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'Synteny' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);

------------------------------------------------------------------------------

CREATE TABLE ApiDB.SyntenicGene (
 syntenic_gene_id            NUMERIC(10),
 synteny_id                  NUMERIC(10),
 na_sequence_id              NUMERIC(10),
 start_min                   NUMERIC,
 end_max                     NUMERIC,
 is_reversed                 NUMERIC(1),
 syn_na_feature_id          NUMERIC(10),
 syn_organism_abbrev         varchar(40),
 modification_date           TIMESTAMP,
 user_read                   NUMERIC(1),
 user_write                  NUMERIC(1),
 group_read                  NUMERIC(1),
 group_write                 NUMERIC(1),
 other_read                  NUMERIC(1),
 other_write                 NUMERIC(1),
 row_user_id                 NUMERIC(12),
 row_group_id                NUMERIC(3),
 row_project_id              NUMERIC(4),
 row_alg_invocation_id       NUMERIC(12),
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
SELECT NEXTVAL('core.tableinfo_sq'), 'SyntenicGene',
       'Standard', 'syntenic_gene_id',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM 
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE LOWER(name) = 'apidb') d
WHERE 'SyntenicGene' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);

 CREATE INDEX SyntGene_f_ix
        ON apidb.SyntenicGene (na_sequence_id, start_min, end_max, synteny_id, syn_na_feature_id, syn_organism_abbrev)
 TABLESPACE INDX;

 CREATE INDEX SyntGene_f2_ix
        ON apidb.SyntenicGene (na_sequence_id, end_max, start_min, synteny_id, syn_na_feature_id, syn_organism_abbrev)
 TABLESPACE INDX;

 CREATE INDEX SyntGene_featix
        ON apidb.SyntenicGene (syn_na_feature_id, syntenic_gene_id)
 TABLESPACE INDX;

 CREATE INDEX SyntGene_synix
        ON apidb.SyntenicGene (synteny_id, syntenic_gene_id)
 TABLESPACE INDX;

------------------------------------------------------------------------------