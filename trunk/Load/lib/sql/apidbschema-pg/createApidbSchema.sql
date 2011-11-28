CREATE SCHEMA ApiDB;
grant usage  on  schema apidb to public;
-- need these?
-- grant select on all tables in schema apidb to public;
-- grant execute on all functions in schema apidb to public;

INSERT INTO core.DatabaseInfo
   (database_id, name, description, modification_date, user_read, user_write,
    group_read, group_write, other_read, other_write, row_user_id,
    row_group_id, row_project_id, row_alg_invocation_id)
   SELECT nextval('core.databaseinfo_sq'), 'ApiDB',
       'Application-specific data for the ApiDB websites', current_timestamp,
       1, 1, 1, 1, 1, 1, 1, 1, (SELECT MAX(project_id) FROM core.ProjectInfo), 0
WHERE lower('ApiDB') NOT IN (SELECT lower(name) FROM core.DatabaseInfo);


-- tuningManager needs there to be a index named "apidb.Blastp_text_ix"
--  (because OracleText needs it)
--CREATE INDEX Blastp_text_ix
--ON core.tableinfo(superclass_table_id, table_id, database_id);

--DROP INDEX core.blastp_index_ix
