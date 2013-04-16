-- These are the definitions of the two tables that make up the registry that
-- resides in the apicomm instances and is used by the tuning manager.
--
-- DO NOT RUN THIS SCRIPT without the express permission of the DBAs. These
-- tables are replicated, and changes in their structure can cause problems
-- with the replication.

create table apidb_r.TuningFamily (
   family_name    character varying(32) primary key,
   subversion_url character varying(200) not null,
   notify_emails  character varying(200) not null,
   is_live        NUMERIC(1),
   config_file    character varying(30));

grant select on apidb_r.TuningFamily to gus_r;
grant insert, update, delete on apidb_r.TuningFamily to gus_w;

create table apidb_r.TuningInstance (
   family_name       character varying(32) not null references apidb_r.TuningFamily,
   instance_nickname character varying(50) not null,
   archived          NUMERIC(1));

grant select on apidb_r.TuningInstance to gus_r;
grant insert, update, delete on apidb_r.TuningInstance to gus_w;

exit
