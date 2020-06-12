
CREATE TABLE apidb.IntronJunction (
intron_junction_id       NUMBER(10),
 protocol_app_node_id         NUMBER(10) NOT NULL,
 na_sequence_id               NUMBER(10) NOT NULL,
 segment_start                     NUMBER(10) NOT NULL,
 segment_end                     NUMBER(10) NOT NULL,
 is_reversed                number(1),
 unique_reads                    NUMBER(10),
 nu_reads                    NUMBER(10),
 MODIFICATION_DATE            DATE,
 USER_READ                    NUMBER(1),
 USER_WRITE                   NUMBER(1),
 GROUP_READ                   NUMBER(1),
 GROUP_WRITE                  NUMBER(1),
 OTHER_READ                   NUMBER(1),
 OTHER_WRITE                  NUMBER(1),
 ROW_USER_ID                  NUMBER(12),
 ROW_GROUP_ID                 NUMBER(3),
 ROW_PROJECT_ID               NUMBER(4),
 ROW_ALG_INVOCATION_ID        NUMBER(12),
 FOREIGN KEY (protocol_app_node_id) REFERENCES Study.ProtocolAppNode,
 PRIMARY KEY (intron_junction_id)
);

CREATE SEQUENCE apidb.IntronJunction_sq;

GRANT insert, select, update, delete ON apidb.IntronJunction TO gus_w;
GRANT select ON apidb.IntronJunction TO gus_r;
GRANT select ON apidb.IntronJunction_sq TO gus_w;

CREATE INDEX apidb.IntJunc_loc_ix
ON apidb.IntronJunction
   (na_sequence_id, segment_start, segment_end, is_reversed)
   TABLESPACE indx;

CREATE INDEX apidb.injun_revix0 ON apidb.IntronJunction (protocol_app_node_id, intron_junction_id) TABLESPACE indx;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'IntronJunction',
       'Standard', 'intron_junction_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'intronjunction' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

------------------------------------------------------------------------------
exit;
