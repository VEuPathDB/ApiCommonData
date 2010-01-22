/* table for alignments ...  */
drop table apidb.NEXTGENSEQ_ALIGN;

create table apidb.NEXTGENSEQ_align (
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
  ROW_ALG_INVOCATION_ID NUMBER(12) NOT NULL
);

grant select on apidb.nextgenseq_align to gus_r;
grant insert, select, update, delete on apidb.nextgenseq_align to gus_w;

create unique index apidb.nextgenseq_align_pk_ids 
on apidb.nextgenseq_align (nextgenseq_align_id)
tablespace indx;

create index apidb.nextgenseq_align_data_idx
on apidb.nextgenseq_align (sample,na_sequence_id,start_a,end_b,intron_size,genome_matches)
tablespace indx;

create index apidb.nextgenseq_align_aonly_idx
on apidb.nextgenseq_align (sample,na_sequence_id,start_a,end_a,genome_matches)
tablespace indx;

/* also need to create the sequence */
create sequence apidb.nextgenseq_align_sq start with 1000 increment by 1;

quit;
