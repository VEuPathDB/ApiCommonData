-- deprecated; have the DBA do this
-- CREATE USER hmdb
-- IDENTIFIED BY "<password>"
-- QUOTA UNLIMITED ON users 
-- QUOTA UNLIMITED ON gus
-- QUOTA UNLIMITED ON indx
-- DEFAULT TABLESPACE users
-- TEMPORARY TABLESPACE temp;

CREATE SCHEMA hmdb;

-- GRANT GUS_R TO hmdb;
-- GRANT GUS_W TO hmdb;
-- GRANT CREATE VIEW TO hmdb;
-- GRANT CREATE MATERIALIZED VIEW TO hmdb;
-- GRANT CREATE TABLE TO hmdb;
-- GRANT CREATE SYNONYM TO hmdb;
-- GRANT CREATE SESSION TO hmdb;
-- GRANT CREATE ANY INDEX TO hmdb;
-- GRANT CREATE TRIGGER TO hmdb;
-- GRANT CREATE ANY TRIGGER TO hmdb;

INSERT INTO core.DatabaseInfo
   (database_id, name, description, modification_date, user_read, user_write,
    group_read, group_write, other_read, other_write, row_user_id,
    row_group_id, row_project_id, row_alg_invocation_id)
SELECT NEXTVAL('core.databaseinfo_sq'), 'hmdb',
       'Application-specific data for the HMDB data', localtimestamp,
       1, 1, 1, 1, 1, 1, 1, 1, p.project_id, 0
FROM (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p
WHERE lower('hmdb') NOT IN (SELECT lower(name) FROM core.DatabaseInfo);


-- GRANTs required for CTXSYS
-- GRANT CONNECT, CTXAPP, GUS_W to hmdb;

-- we aren't sure we need this, and would rather not:
-- GRANT RESOURCE to hmdb;

-- ALTER USER hmdb ACCOUNT LOCK;
