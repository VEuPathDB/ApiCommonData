
CREATE TABLE apidb.IntronJunction (
intron_junction_id       NUMBER(10),
 external_database_release_id NUMBER(10) NOT NULL,
 sample_name                  VARCHAR2(100) NOT NULL,
 na_sequence_id               NUMBER(10) NOT NULL,
 mapping_start                     NUMBER(10) NOT NULL,
 mapping_end                     NUMBER(10) NOT NULL,
 is_reversed                number(1),
 score                    NUMBER(10),
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
 FOREIGN KEY (external_database_release_id) REFERENCES SRes.ExternalDatabaseRelease,
 PRIMARY KEY (intron_junction_id)
);

CREATE SEQUENCE apidb.IntronJunction_sq;

GRANT insert, select, update, delete ON apidb.IntronJunction TO gus_w;
GRANT select ON apidb.IntronJunction TO gus_r;
GRANT select ON apidb.IntronJunction_sq TO gus_w;

CREATE INDEX apidb.rif_rls_ix
ON apidb.IntronJunction
   (external_database_release_id, na_sequence_id, sample_name, mapping_start, 
    mapping_end, intron_junction_id, score, is_reversed, unique_reads, nu_reads
);


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
