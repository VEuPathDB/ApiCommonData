create table Apidb.NextGenSeqCoverage (
next_gen_seq_coverage_id NUMBER(10),
external_database_release_id number(10) not null,
sample varchar(30) not null,
na_sequence_id number(10) not null,
mapping_start number(10) not null,
mapping_end number(10) not null,
is_reversed number(3),
coverage number not null,
multiple number(1),
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
ROW_ALG_INVOCATION_ID NUMBER(12) NOT NULL,
 PRIMARY KEY (next_gen_seq_coverage_id)
);


CREATE SEQUENCE ApiDB.NextGenSeqCoverage_sq;

grant insert, select, update, delete on Apidb.NextGenSeqCoverage to gus_w;
grant select on Apidb.NextGenSeqCoverage to gus_r;
GRANT select ON ApiDB.NextGenSeqCoverage_sq TO gus_w;

create index apidb.nextgenseqcov_indx
on Apidb.NextGenSeqCoverage (external_database_release_id,sample,na_sequence_id,mapping_start,mapping_end,coverage,multiple)
tablespace indx;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'NextGenSeqCoverage',
       'Standard', 'next_gen_seq_coverage_id ',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'NextGenSeqCoverage' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);

exit;
