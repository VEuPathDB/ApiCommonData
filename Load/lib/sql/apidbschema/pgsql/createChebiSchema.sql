-- depreacated; have the DBAs do this
-- CREATE USER chebi
-- IDENTIFIED BY "<password>"
-- QUOTA UNLIMITED ON users 
-- QUOTA UNLIMITED ON gus
-- QUOTA UNLIMITED ON indx
-- DEFAULT TABLESPACE users
-- TEMPORARY TABLESPACE temp;

CREATE SCHEMA chebi;

-- GRANT GUS_R TO chebi;
-- GRANT GUS_W TO chebi;
-- GRANT CREATE VIEW TO chebi;
-- GRANT CREATE MATERIALIZED VIEW TO chebi;
-- GRANT CREATE TABLE TO chebi;
-- GRANT CREATE SYNONYM TO chebi;
-- GRANT CREATE SESSION TO chebi;
-- GRANT CREATE ANY INDEX TO chebi;
-- GRANT CREATE TRIGGER TO chebi;
-- GRANT CREATE ANY TRIGGER TO chebi;

INSERT INTO core.DatabaseInfo
   (database_id, name, description, modification_date, user_read, user_write,
    group_read, group_write, other_read, other_write, row_user_id,
    row_group_id, row_project_id, row_alg_invocation_id)
SELECT NEXTVAL('core.databaseinfo_sq'), 'chEBI',
       'Application-specific data for the chEBI data', localtimestamp,
       1, 1, 1, 1, 1, 1, 1, 1, p.project_id, 0
FROM (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p
WHERE lower('chEBI') NOT IN (SELECT lower(name) FROM core.DatabaseInfo);


-- GRANTs required for CTXSYS
-- GRANT CONNECT, RESOURCE, CTXAPP, GUS_W to chebi;

-- alter user chebi quota unlimited on indx;
