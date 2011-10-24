/* table for alignments ...  */
create table Apidb.NextGenSeq_Align (
  nextgenseq_align_id number(10) not null,
  external_database_release_id number(10) not null,
  sample varchar(30) not null,
  na_sequence_id number(10) not null,
  query_id varchar(30) not null,
  strand char(1),
  start_a number(10) not null,
  end_a number(10) not null,
  start_b number(10),
  end_b number(10),
  intron_size number(10),
  genome_matches number(10) not null,
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
 PRIMARY KEY (nextgenseq_align_id)
);

grant select on Apidb.NextGenSeq_Align to gus_r;
grant insert, select, update, delete on Apidb.NextGenSeq_Align to gus_w;

create index apidb.nextgenseq_align_data_idx
on Apidb.NextGenSeq_Align (sample,na_sequence_id,start_a,end_b,intron_size,genome_matches)
tablespace indx;

create index apidb.nextgenseq_align_aonly_idx
on Apidb.NextGenSeq_Align (sample,na_sequence_id,start_a,end_a,genome_matches)
tablespace indx;

/* also need to create the sequence */
create sequence apidb.nextgenseq_align_sq start with 1000 increment by 1;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'NextGenSeq_Align',
       'Standard', 'nextgenseq_align_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'NextGenSeq_Align' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);

quit;
