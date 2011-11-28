/* table for alignments ...  */
drop table Apidb.NextGenSeq_Align;

create table Apidb.NextGenSeq_Align (
  nextgenseq_align_id NUMERIC(10) not null,
  external_database_release_id NUMERIC(10) not null,
  sample varchar(30) not null,
  na_sequence_id NUMERIC(10) not null,
  query_id varchar(30) not null,
  strand char(1),
  start_a NUMERIC(10) not null,
  end_a NUMERIC(10) not null,
  start_b NUMERIC(10),
  end_b NUMERIC(10),
  intron_size NUMERIC(10),
  genome_matches NUMERIC(10) not null,
 MODIFICATION_DATE     TIMESTAMP,
 USER_READ             NUMERIC(1),
 USER_WRITE            NUMERIC(1),
 GROUP_READ            NUMERIC(1),
 GROUP_WRITE           NUMERIC(1),
 OTHER_READ            NUMERIC(1),
 OTHER_WRITE           NUMERIC(1),
 ROW_USER_ID           NUMERIC(12),
 ROW_GROUP_ID          NUMERIC(3),
 ROW_PROJECT_ID        NUMERIC(4),
 ROW_ALG_INVOCATION_ID NUMERIC(12) NOT NULL,
 PRIMARY KEY (nextgenseq_align_id)
);


create unique index nextgenseq_align_pk_ids 
on Apidb.NextGenSeq_Align (nextgenseq_align_id);

CREATE INDEX nextgenseq_align_data_idx
on Apidb.NextGenSeq_Align (sample,na_sequence_id,start_a,end_b,intron_size,genome_matches);

CREATE INDEX nextgenseq_align_aonly_idx
on Apidb.NextGenSeq_Align (sample,na_sequence_id,start_a,end_a,genome_matches);

/* also need to create the sequence */
create sequence apidb.nextgenseq_align_sq start with 1000 increment by 1;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT nextval('core.tableinfo_sq'), 'NextGenSeq_Align',
       'Standard', 'nextgenseq_align_id',
       (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb'), 0, 0, NULL, NULL, 
       1,current_timestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo), 0
WHERE lower('NextGenSeq_Align') NOT IN (SELECT lower(name) FROM core.TableInfo
        WHERE database_id = (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb'));


