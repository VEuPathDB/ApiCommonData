
------------------------------------------------------------------------------

CREATE TABLE ApiDB.Synteny (
 synteny_id  NUMERIC(10),
 external_database_release_id NUMERIC(10),
 a_na_sequence_id  NUMERIC(10),	
 b_na_sequence_id  NUMERIC(10),	
 a_start NUMERIC(8),
 a_end NUMERIC(8),
 b_start NUMERIC(8),
 b_end NUMERIC(8),
 is_reversed NUMERIC(3),
 MODIFICATION_DATE     timestamp,
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
ON apidb.Synteny (b_na_sequence_id, synteny_id);

CREATE INDEX synteny_revix2
ON apidb.Synteny (external_database_release_id, synteny_id);

CREATE SEQUENCE ApiDB.Synteny_sq;


CREATE INDEX syn_ix
ON apidb.Synteny(a_na_sequence_id, a_start, a_end, external_database_release_id);


INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT nextval('core.tableinfo_sq'), 'Synteny',
       'Standard', 'synteny_id',
       (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb'), 0, 0, NULL, NULL, 
       1,current_timestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo), 0
WHERE lower('Synteny') NOT IN (SELECT lower(name) FROM core.TableInfo
        WHERE database_id = (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb'));



------------------------------------------------------------------------------

CREATE TABLE ApiDB.SyntenyAnchor (
 synteny_anchor_id            NUMERIC(10),
 synteny_id                   NUMERIC(10),
 syntenic_loc                 NUMERIC(12),
 prev_ref_loc                 NUMERIC(12),
 ref_loc                      NUMERIC(12),
 next_ref_loc                 NUMERIC(12),
 modification_date            timestamp,
 user_read                    NUMERIC(1),
 user_write                   NUMERIC(1),
 group_read                   NUMERIC(1),
 group_write                  NUMERIC(1),
 other_read                   NUMERIC(1),
 other_write                  NUMERIC(1),
 row_user_id                  NUMERIC(12),
 row_group_id                 NUMERIC(3),
 row_project_id               NUMERIC(4),
 row_alg_invocation_id        NUMERIC(12),
 FOREIGN KEY (synteny_id) REFERENCES apidb.Synteny (synteny_id),
 PRIMARY KEY (synteny_anchor_id)
);

CREATE SEQUENCE ApiDB.SyntenyAnchor_sq;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT nextval('core.tableinfo_sq'), 'SyntenyAnchor',
       'Standard', 'synteny_anchor_id',
       (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb'), 0, 0, NULL, NULL, 
       1,current_timestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo), 0
WHERE lower('SyntenyAnchor') NOT IN (SELECT lower(name) FROM core.TableInfo
        WHERE database_id = (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb'));




CREATE INDEX SyntAnch_front_ix
       ON apidb.SyntenyAnchor (synteny_id, ref_loc, next_ref_loc);
CREATE INDEX SyntAnch_back_ix
       ON apidb.SyntenyAnchor (synteny_id, ref_loc, prev_ref_loc);
------------------------------------------------------------------------------
