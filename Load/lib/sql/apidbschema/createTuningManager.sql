create table apidb.TuningDefinition (
   name       varchar2(65) primary key,
   timestamp  date not null,
   definition clob not null);

create table apidb.ObsoletedTuningTables (
   name      varchar2(65) primary key,
   timestamp date not null);

create sequence apidb.TuningManager_sq
   start with 1111;

create table apidb.ExternalDependency (
   name         varchar2(65) primary key,
   max_mod_date date not null,
   timestamp    date not null,
   row_count    number not null);

exit
