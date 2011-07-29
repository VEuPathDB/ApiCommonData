-- These are the definitions of the two tables that make up the registry that
-- resides in the apicomm instances and is used by the tuning manager.
--
-- DO NOT RUN THIS SCRIPT without the express permission of the DBAs. These
-- tables are replicated, and changes in their structure can cause problems
-- with the replication.

create table apidb_r.TuningFamily (
   family_name    varchar2(32) primary key,
   subversion_url varchar2(200) not null,
   notify_emails  varchar2(200) not null,
   is_live        number(1),
   config_file    varchar2(30));

grant select on apidb_r.TuningFamily to gus_r;
grant insert, update, delete on apidb_r.TuningFamily to gus_w;

create table apidb_r.TuningInstance (
   family_name       varchar2(32) not null references apidb_r.TuningFamily,
   last_update       date,
   last_updater      varchar2(50),
   last_check        date,
   last_checker      varchar2(50),
   instance_nickname varchar2(50) not null,
   last_ok           date,
   outdated_since    date,
   archived          number(1));

grant select on apidb_r.TuningInstance to gus_r;
grant insert, update, delete on apidb_r.TuningInstance to gus_w;

exit
