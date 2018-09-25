CREATE TABLE apidb.DatabaseTableMapping (
       database_table_mapping_id number(20),
       database_orig varchar2(10), 
       table_name varchar2(35), 
       primary_key_orig number(20), 
       primary_key number(20),
       global_natural_key varchar2(100),
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
 PRIMARY KEY (database_table_mapping_id)  
 );


GRANT INSERT, SELECT, UPDATE, DELETE ON ApiDB.DatabaseTableMapping TO gus_w;
GRANT SELECT ON ApiDB.DatabaseTableMapping TO gus_r;

CREATE INDEX apidb.db_tbl_map_idx
ON ApiDB.DatabaseTableMapping (database_orig, table_name, primary_key_orig, primary_key) tablespace indx;

CREATE SEQUENCE apidb.DatabaseTableMapping_sq;

GRANT SELECT ON apidb.DATABASETABLEMAPPING_sq TO gus_r;
GRANT SELECT ON apidb.DATABASETABLEMAPPING_sq TO gus_w;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'DATABASETABLEMAPPING',
       'Standard', 'database_table_mapping_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'databasetablemapping' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);



exit;
