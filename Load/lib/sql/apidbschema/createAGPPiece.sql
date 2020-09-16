CREATE TABLE ApiDB.AGPPiece (
 agp_piece_id NUMBER(10) not null,
 source_id varchar2(80) not null,
 start_min number(12) not null,
 end_max number(12) not null,
 part_number number(5) not null,
 part_type varchar2(1) not null,
 piece_id varchar2(80),
 piece_start  number(12),
 piece_end  number(12),
 is_reversed number(1),
 gap_length  number(12),
 gap_type varchar2(20),
 has_linkage number(1),
 linkage_evidence varchar2(20),
 external_database_release_id NUMBER(10) NOT NULL,
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
 PRIMARY KEY (agp_piece_id)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON ApiDB.AGPPiece TO gus_w;
GRANT SELECT ON ApiDB.AGPPiece TO gus_r;

CREATE SEQUENCE apidb.AGPPiece_sq;

GRANT SELECT ON apidb.AGPPiece_sq TO gus_r;
GRANT SELECT ON apidb.AGPPiece_sq TO gus_w;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'AGPPiece',
       'Standard', 'agp_piece_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'agppiece' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);


exit;
