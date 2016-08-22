CREATE TABLE ApiDB.IsolateGPS (
 isolate_gps_id        NUMBER(10)   NOT NULL,
 gazetteer_id          VARCHAR(250) NOT NULL,
 country               VARCHAR(250) NOT NULL,
 lat                   FLOAT        NOT NULL,
 lng                   FLOAT        NOT NULL,
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
 PRIMARY KEY (isolate_gps_id)
);

CREATE SEQUENCE ApiDB.IsolateGPS_sq;

GRANT insert, select, update, delete ON ApiDB.IsolateGPS TO gus_w;
GRANT select ON ApiDB.IsolateGPS TO gus_r;
GRANT select ON ApiDB.IsolateGPS_sq TO gus_w;

------------------------------------------------------------------------------

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'IsolateGPS',
       'Standard', 'ISOLATE_GPS_ID',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'isolategps' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    where database_id = d.database_id);



exit;
