create table apidb.TuningTable (
   name          varchar(65) primary key,
   timestamp     timestamp not null,
   definition    text not null,
   status        varchar(20),
   last_check    timestamp,
   check_os_user varchar(20)
  );

grant select on apidb.TuningTable to gus_r;
grant insert, update, delete on apidb.TuningTable to gus_w;

create table apidb.ObsoleteTuningTable (
   name      varchar(65) primary key,
   timestamp date not null);

grant select on apidb.ObsoleteTuningTable to gus_r;
grant insert, update, delete on apidb.ObsoleteTuningTable to gus_w;

create sequence apidb.TuningManager_sq
   start with 1111;

grant select on apidb.TuningManager_sq to gus_w;

create table apidb.TuningMgrExternalDependency (
   name         varchar(65) primary key,
   max_mod_date timestamp,
   timestamp    timestamp not null,
   row_count    numeric not null);

grant select on apidb.TuningMgrExternalDependency to gus_r;
grant insert, update, delete on apidb.TuningMgrExternalDependency to gus_w;

-- TODO There's no direct equivalent of service_name in pgsql. We can get the server ip address with inet_server_addr()
-- TODO but not the host name. Also, maybe this may be irrelevant in pgsql context.
-- create table apidb.InstanceMetaInfo as
-- select sys_context ('USERENV', 'SERVICE_NAME') as instance_nickname,
--        cast(null as varchar2(50)) as current_updater,
--        cast(null as date) as update_start,
--        cast(null as varchar2(20)) as project_id,
--        cast(null as varchar2(12)) as version
-- from dual;

-- grant select on apidb.InstanceMetaInfo to gus_r;
-- grant insert, update, delete on apidb.InstanceMetaInfo to gus_w;
