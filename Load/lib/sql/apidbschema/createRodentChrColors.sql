CREATE TABLE ApiDB.RodentChrColors (
 rodentChrColors_id	NUMBER(10),
 chromosome  varchar(10) NOT NULL,
 color       varchar(20), 
 value	     varchar(10),
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
 PRIMARY KEY (rodentChrColors_id)
);

CREATE SEQUENCE ApiDB.RodentChrColors_sq;

GRANT insert, select, update, delete ON ApiDB.RodentChrColors TO gus_w;
GRANT select ON ApiDB.RodentChrColors TO gus_r;
GRANT select ON ApiDB.RodentChrColors_sq TO gus_w;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'RodentChrColors',
       'Standard', 'rodentChrColors_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'RodentChrColors' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    where database_id = d.database_id);

exit;
