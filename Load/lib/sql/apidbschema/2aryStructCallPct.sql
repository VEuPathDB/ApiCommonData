alter table dots.secondarystructurecall add (percentage number(3));

drop table dots.tmp_ssc;

create table dots.tmp_ssc as
select secondary_structure_call_id, secondary_structure_id, structure_type,
       call_confidence, percentage, modification_date, user_read, user_write,
       group_read, group_write, other_read, other_write, row_user_id,
       row_group_id, row_project_id, row_alg_invocation_id
from dots.SecondaryStructureCall;

drop table dots.SecondaryStructureCall;

create table dots.SecondaryStructureCall as select * from dots.tmp_ssc;
grant select on dots.SecondaryStructureCall to gus_r;

grant insert, update, delete on dots.SecondaryStructureCall to gus_w;

alter table dots.SecondaryStructureCall add 

alter table DoTS.SecondaryStructureCall
add constraint SecStructCall_pk primary key (SECONDARY_STRUCTURE_CALL_ID);

alter table dots.SecondaryStructureCall
add constraint SecStructCall_fk foreign key (SECONDARY_STRUCTURE_ID)
references DOTS.SECONDARYSTRUCTURE (SECONDARY_STRUCTURE_ID);

create index ssc_secStruc_ix on dots.SecondaryStructureCall (secondary_structure_id);

exit
