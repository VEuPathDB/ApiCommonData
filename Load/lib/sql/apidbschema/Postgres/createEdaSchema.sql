-- deprecated; have the DBAs do this
-- CREATE USER EDA
-- IDENTIFIED BY "<password>"
-- QUOTA UNLIMITED ON users 
-- QUOTA UNLIMITED ON gus
-- QUOTA UNLIMITED ON indx
-- DEFAULT TABLESPACE users
-- TEMPORARY TABLESPACE temp;

CREATE SCHEMA eda;

-- GRANT GUS_R TO EDA;
-- GRANT GUS_W TO EDA;
-- GRANT CREATE VIEW TO EDA;
-- GRANT CREATE MATERIALIZED VIEW TO EDA;
-- GRANT CREATE TABLE TO EDA;
-- GRANT CREATE SYNONYM TO EDA;
-- GRANT CREATE SESSION TO EDA;
-- GRANT CREATE ANY INDEX TO EDA;
-- GRANT CREATE TRIGGER TO EDA;
-- GRANT CREATE ANY TRIGGER TO EDA;

-- GRANT REFERENCES ON sres.externaldatabaserelease TO eda;
-- GRANT REFERENCES ON sres.ontologyterm TO eda;

INSERT INTO core.DatabaseInfo
   (database_id, name, description, modification_date, user_read, user_write,
    group_read, group_write, other_read, other_write, row_user_id,
    row_group_id, row_project_id, row_alg_invocation_id)
SELECT NEXTVAL('core.databaseinfo_sq'), 'EDA',
       'Application-specific data for the EDA websites', localtimestamp,
       1, 1, 1, 1, 1, 1, 1, 1, p.project_id, 0
FROM (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p
WHERE lower('eda') NOT IN (SELECT lower(name) FROM core.DatabaseInfo);

-- GRANTs required for CTXSYS
-- GRANT CONNECT, RESOURCE, CTXAPP, GUS_W to eda;

-- alter user EDA quota unlimited on indx;