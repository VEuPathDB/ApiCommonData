CREATE TABLE ApiDB.PlasmoPfalLocations (
 plasmoPfalLocations_id      NUMERIC(10),
 seq_source_id  character varying(20) NOT NULL,
 old_location          NUMERIC(10)  NOT NULL,
 new_location        NUMERIC(10) NOT NULL,
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
 ROW_ALG_INVOCATION_ID NUMERIC(12) NOT NULL,
 PRIMARY KEY (plasmoPfalLocations_id)
);

CREATE SEQUENCE ApiDB.PlasmoPfalLocations_sq;


INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT nextval('core.tableinfo_sq'), 'PlasmoPfalLocations',
       'Standard', 'plasmoPfalLocations_id',
       (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb'), 0, 0, NULL, NULL, 
       1,current_timestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo), 0
WHERE lower('PlasmoPfalLocations') NOT IN (SELECT lower(name) FROM core.TableInfo
        WHERE database_id = (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb'));


