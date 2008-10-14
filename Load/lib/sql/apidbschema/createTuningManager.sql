create table apidb.TuningTable (
   name       varchar2(65) primary key,
   timestamp  date not null,
   definition clob not null);

create table apidb.ObsoleteTuningTable (
   name      varchar2(65) primary key,
   timestamp date not null);

create sequence apidb.TuningManager_sq
   start with 1111;

create table apidb.TuningMgrExternalDependency (
   name         varchar2(65) primary key,
   max_mod_date date,
   timestamp    date not null,
   row_count    number not null);

create table apidb.InstanceMetaInfo as
select substr(sys_context ('USERENV', 'SERVICE_NAME'), 1, instr(sys_context ('USERENV', 'SERVICE_NAME'), '.')-1) as instance_name,
       sys_context ('USERENV', 'SERVICE_NAME') as service_name,
       cast(null as varchar2(50)) as validation_key,
       cast(null as varchar2(50)) as current_updater
from dual;

exit
