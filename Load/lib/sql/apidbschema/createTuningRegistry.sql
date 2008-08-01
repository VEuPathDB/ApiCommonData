drop table apidb.TuningInstance;
drop table apidb.TuningFamily;

create table apidb.TuningFamily (
   family_name    varchar2(32) primary key,
   subversion_url varchar2(200) not null,
   notify_emails  varchar2(200) not null);

grant select on apidb.TuningFamily to gus_r;
grant insert, update, delete on apidb.TuningFamily to gus_w;

create table apidb.TuningInstance (
   instance_name varchar2(32) primary key,
   family_name   varchar2(32) not null references apidb.TuningFamily,
   service_name  varchar2(85) not null);

grant select on apidb.TuningFamily to gus_r;
grant insert, update, delete on apidb.TuningFamily to gus_w;

exit
