CREATE USER TestTuning
IDENTIFIED BY VALUES 'F7CDFE1532397A1C'   -- encoding of standard password
QUOTA UNLIMITED ON users 
QUOTA UNLIMITED ON gus
QUOTA UNLIMITED ON indx
DEFAULT TABLESPACE users
TEMPORARY TABLESPACE temp;

GRANT GUS_R TO TestTuning;
GRANT GUS_W TO TestTuning;
GRANT CREATE VIEW TO TestTuning;
GRANT CREATE MATERIALIZED VIEW TO TestTuning;
GRANT CREATE TABLE TO TestTuning;
GRANT CREATE SYNONYM TO TestTuning;
GRANT CREATE SESSION TO TestTuning;
GRANT CREATE ANY INDEX TO TestTuning;
GRANT CREATE TRIGGER TO TestTuning;
GRANT CREATE ANY TRIGGER TO TestTuning;

GRANT REFERENCES ON dots.GeneFeature TO TestTuning;
GRANT REFERENCES ON dots.NaFeature TO TestTuning;
GRANT REFERENCES ON dots.NaFeatureNaGene TO TestTuning;
GRANT REFERENCES ON dots.AaSequenceImp TO TestTuning;
GRANT REFERENCES ON sres.Taxon TO TestTuning;

-- GRANTs required for CTXSYS
GRANT CONNECT, RESOURCE, CTXAPP, GUS_W to TestTuning;

INSERT INTO core.DatabaseInfo
   (database_id, name, description, modification_date, user_read, user_write,
    group_read, group_write, other_read, other_write, row_user_id,
    row_group_id, row_project_id, row_alg_invocation_id)
SELECT core.databaseinfo_sq.nextval, 'TestTuning',
       'schema for tables created by tuning manager', sysdate,
       1, 1, 1, 1, 1, 1, 1, 1, p.project_id, 0
FROM dual, (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p
WHERE lower('TestTuning') NOT IN (SELECT lower(name) FROM core.DatabaseInfo);

alter user TestTuning quota unlimited on indx;

exit
