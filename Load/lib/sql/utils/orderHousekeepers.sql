-- For GUS tables which have had columns added after the "housekeeping" columns,
-- this script rearranges the columns so that the housekeeping columns are last,
-- where GUS plugins like them.

ALTER TABLE &1
ADD (
 new_modification_date            DATE,
 new_user_read                    NUMBER(1),
 new_user_write                   NUMBER(1),
 new_group_read                   NUMBER(1),
 new_group_write                  NUMBER(1),
 new_other_read                   NUMBER(1),
 new_other_write                  NUMBER(1),
 new_row_user_id                  NUMBER(12),
 new_row_group_id                 NUMBER(3),
 new_row_project_id               NUMBER(4),
 new_row_alg_invocation_id        NUMBER(12)
);

update &1 set
new_modification_date = modification_date,
new_user_read = user_read,
new_user_write = user_write,
new_group_read = group_read,
new_group_write = group_write,
new_other_read = other_read,
new_other_write = other_write,
new_row_user_id = row_user_id,
new_row_group_id = row_group_id,
new_row_project_id = row_project_id,
new_row_alg_invocation_id = row_alg_invocation_id;

ALTER TABLE &1
DROP (
modification_date,
user_read, 
user_write, 
group_read, 
group_write, 
other_read, 
other_write, 
row_user_id, 
row_group_id, 
row_project_id, 
row_alg_invocation_id
);

ALTER TABLE &1
ADD (
 modification_date            DATE,
 user_read                    NUMBER(1),
 user_write                   NUMBER(1),
 group_read                   NUMBER(1),
 group_write                  NUMBER(1),
 other_read                   NUMBER(1),
 other_write                  NUMBER(1),
 row_user_id                  NUMBER(12),
 row_group_id                 NUMBER(3),
 row_project_id               NUMBER(4),
 row_alg_invocation_id        NUMBER(12)
);

update &1 set
modification_date = new_modification_date,
user_read = new_user_read,
user_write = new_user_write,
group_read = new_group_read,
group_write = new_group_write,
other_read = new_other_read,
other_write = new_other_write,
row_user_id = new_row_user_id,
row_group_id = new_row_group_id,
row_project_id = new_row_project_id,
row_alg_invocation_id = new_row_alg_invocation_id;

ALTER TABLE &1
DROP (
new_modification_date,
new_user_read, 
new_user_write, 
new_group_read, 
new_group_write, 
new_other_read, 
new_other_write, 
new_row_user_id, 
new_row_group_id, 
new_row_project_id, 
new_row_alg_invocation_id
);
