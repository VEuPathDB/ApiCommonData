create table apidb.TuningTable (
   name       character varying(65) primary key,
   timestamp  timestamp not null,
   definition text not null);


create table apidb.ObsoleteTuningTable (
   name      character varying(65) primary key,
   timestamp timestamp not null);


create sequence apidb.TuningManager_sq
   start with 1111;


create table apidb.TuningMgrExternalDependency (
   name         character varying(65) primary key,
   max_mod_date timestamp,
   timestamp    timestamp not null,
   row_count    NUMERIC not null);


create table apidb.InstanceMetaInfo as
select cast(current_database() as character varying(256)) as instance_nickname,
       cast(null as character varying(50)) as current_updater,
       cast(null as timestamp) as update_start,
       cast(null as character varying(20)) as project_id,
       cast(null as character varying(12)) as version;

