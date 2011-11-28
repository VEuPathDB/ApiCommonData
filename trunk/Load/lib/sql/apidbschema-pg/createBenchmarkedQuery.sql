create table apidb.BenchmarkedQuery (
  bqid            NUMERIC(12) not null,
  project         character varying(30) not null,
  query           clob not null,
  trace           character varying(500),
  consistent_gets NUMERIC,
  plan            clob,
  instance        character varying(50),
  login           character varying(50),
  hide            NUMERIC(1),
  nickname        character varying(50),
  description     character varying(4000),
  rows_returned   NUMERIC,
  prepare_time    float,
  execute_time    float,
  fetch_time      float,
  total_time      float,
  run_date        timestamp);

grant select on apidb.BenchmarkedQuery to gus_r;
grant insert, update, delete on apidb.BenchmarkedQuery to gus_w;

create sequence apidb.BenchmarkedQuery_sq;
