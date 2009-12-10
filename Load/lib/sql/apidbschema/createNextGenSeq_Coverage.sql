create table apidb.nextgenseq_coverage (
external_database_release_id number(10) not null,
sample varchar(30) not null,
na_sequence_id number(10) not null,
location number(10) not null,
coverage number not null,
multiple number(1),
ROW_ALG_INVOCATION_ID NUMBER(12) NOT NULL
);

grant insert, select, update, delete on apidb.nextgenseq_coverage to gus_w;
grant select on apidb.nextgenseq_coverage to gus_r;

create index apidb.nextgenseq_cov_indx
on apidb.nextgenseq_coverage (external_database_release_id,sample,na_sequence_id,location,coverage,multiple)
tablespace indx;

exit;
