-- deprecated; have the DBAs do this
-- CREATE USER EDA_UD
-- IDENTIFIED BY "<password>"
-- QUOTA UNLIMITED ON users 
-- QUOTA UNLIMITED ON gus
-- QUOTA UNLIMITED ON indx
-- DEFAULT TABLESPACE users
-- TEMPORARY TABLESPACE temp;

GRANT GUS_R TO EDA_UD;
GRANT GUS_W TO EDA_UD;
GRANT CREATE VIEW TO EDA_UD;
GRANT CREATE MATERIALIZED VIEW TO EDA_UD;
GRANT CREATE TABLE TO EDA_UD;
GRANT CREATE SYNONYM TO EDA_UD;
GRANT CREATE SESSION TO EDA_UD;
GRANT CREATE ANY INDEX TO EDA_UD;
GRANT CREATE TRIGGER TO EDA_UD;
GRANT CREATE ANY TRIGGER TO EDA_UD;


GRANT REFERENCES ON sres.externaldatabaserelease TO eda_ud;
GRANT REFERENCES ON sres.ontologyterm TO eda_ud;
GRANT REFERENCES ON apidbUserDatasets.InstalledUserDataset TO eda_ud;

INSERT INTO core.DatabaseInfo
   (database_id, name, description, modification_date, user_read, user_write,
    group_read, group_write, other_read, other_write, row_user_id,
    row_group_id, row_project_id, row_alg_invocation_id)
SELECT core.databaseinfo_sq.nextval, 'EDA_UD',
       'Application-specific data for the EDA_UD websites', sysdate,
       1, 1, 1, 1, 1, 1, 1, 1, p.project_id, 0
FROM dual, (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p
WHERE lower('eda_ud') NOT IN (SELECT lower(name) FROM core.DatabaseInfo);

-- GRANTs required for CTXSYS
GRANT CONNECT, RESOURCE, CTXAPP, GUS_W to eda_ud;

alter user EDA_UD quota unlimited on indx;

exit
