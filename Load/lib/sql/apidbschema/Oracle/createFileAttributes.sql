CREATE TABLE apidb.FileAttributes (
  file_id     varchar(100),
  filename    varchar(200),
  filepath    varchar(200),
  organism    varchar(100),
  build_num   NUMBER(3),
  category    varchar(50),
  file_type   varchar(50),
  file_format varchar(10),
  filesize    NUMBER(10),
  checksum    varchar(100),
 PRIMARY KEY (file_id)
);


GRANT insert, select, update, delete ON apidb.FileAttributes TO gus_w;
GRANT select ON apidb.FileAttributes TO gus_r;
GRANT select ON apidb.FileAttributes TO gus_w;



INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'FileAttributes',
       'Standard', 'file_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'fileattributes' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);


exit;
