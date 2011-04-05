create table apidb.BenchmarkedQuery (
  bqid            number(12) not null,
  project         varchar2(30) not null,
  query           clob not null,
  trace           varchar2(500),
  consistent_gets number,
  plan            clob,
  instance        varchar2(50),
  login           varchar2(50),
  hide            number(1),
  nickname        varchar2(50),
  description     varchar2(4000),
  rows_returned   number,
  prepare_time    float,
  execute_time    float,
  fetch_time      float,
  total_time      float,
  run_date        date);

grant select on apidb.BenchmarkedQuery to gus_r;
grant insert, update, delete on apidb.BenchmarkedQuery to gus_w;

create sequence apidb.BenchmarkedQuery_sq;
