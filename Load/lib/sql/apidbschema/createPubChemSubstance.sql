CREATE TABLE bindu.PubChemSubstance (
 substance_id            NUMBER(10),
 property                VARCHAR2(20) NOT NULL,
 value                   VARCHAR2(100) NOT NULL,
 MODIFICATION_DATE       DATE,
 USER_READ               NUMBER(1),
 USER_WRITE              NUMBER(1),
 GROUP_READ              NUMBER(1),
 GROUP_WRITE             NUMBER(1),
 OTHER_READ              NUMBER(1),
 OTHER_WRITE             NUMBER(1),
 ROW_USER_ID             NUMBER(12),
 ROW_GROUP_ID            NUMBER(3),
 ROW_PROJECT_ID          NUMBER(4),
 ROW_ALG_INVOCATION_ID   NUMBER(12),
 PRIMARY KEY (substance_id)
);

GRANT insert, select, update, delete ON bindu.PubChemSubstance TO gus_w;
GRANT select ON bindu.PubChemSubstance TO gus_r;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'PubChemSubstance',
       'Standard', 'substance_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'bindu') d
WHERE 'PubChemSubstance' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);

------------------------------------------------------------------------------
exit;
