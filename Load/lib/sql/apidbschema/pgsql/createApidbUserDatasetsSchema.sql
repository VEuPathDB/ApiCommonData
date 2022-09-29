-- deprecated; have the DBAs do this
-- CREATE USER ApidbUserDatasets
-- IDENTIFIED BY VALUES "<password>"
-- QUOTA UNLIMITED ON users 
-- QUOTA UNLIMITED ON gus
-- QUOTA UNLIMITED ON indx
-- DEFAULT TABLESPACE users
-- TEMPORARY TABLESPACE temp;

CREATE SCHEMA apidbuserdatasets;

-- GRANT GUS_R TO ApidbUserDatasets;
-- GRANT GUS_W TO ApidbUserDatasets;
-- GRANT CREATE VIEW TO ApidbUserDatasets;
-- GRANT CREATE MATERIALIZED VIEW TO ApidbUserDatasets;
-- GRANT CREATE ANY TABLE TO ApidbUserDatasets;
-- GRANT CREATE SYNONYM TO ApidbUserDatasets;
-- GRANT CREATE SESSION TO ApidbUserDatasets;
-- GRANT CREATE ANY INDEX TO ApidbUserDatasets;
-- GRANT CREATE TRIGGER TO ApidbUserDatasets;
-- GRANT CREATE ANY TRIGGER TO ApidbUserDatasets;

-- GRANT REFERENCES on sres.ontologyterm to ApidbUserDatasets;
-- GRANT REFERENCES on sres.ExternalDatabaseRelease to ApidbUserDatasets;

INSERT INTO core.DatabaseInfo
   (database_id, name, description, modification_date, user_read, user_write,
    group_read, group_write, other_read, other_write, row_user_id,
    row_group_id, row_project_id, row_alg_invocation_id)
SELECT NEXTVAL('core.databaseinfo_sq'), 'ApidbUserDatasets',
       'schema for tables used by user datasets', localtimestamp,
       1, 1, 1, 1, 1, 1, 1, 1, p.project_id, 0
FROM (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p
WHERE lower('ApidbUserDatasets') NOT IN (SELECT lower(name) FROM core.DatabaseInfo);