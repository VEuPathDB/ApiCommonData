CREATE USER ApiDB
IDENTIFIED BY temppass
QUOTA UNLIMITED ON users 
QUOTA UNLIMITED ON gus
DEFAULT TABLESPACE gus
TEMPORARY TABLESPACE temp;

GRANT SCHEMA_OWNER TO ApiDB;
GRANT GUS_R TO ApiDB;
GRANT GUS_W TO ApiDB;
GRANT CREATE VIEW TO ApiDB;
GRANT CREATE MATERIALIZED VIEW TO ApiDB;
GRANT CREATE TABLE TO ApiDB;
GRANT CREATE SYNONYM TO ApiDB;
GRANT CREATE SESSION TO ApiDB;
GRANT CREATE ANY INDEX TO ApiDB;

GRANT REFERENCES ON dots.GeneFeature TO ApiDB;
GRANT REFERENCES ON dots.NaFeature TO ApiDB;
GRANT REFERENCES ON dots.NaFeatureNaGene TO ApiDB;
GRANT REFERENCES ON dots.AaSequenceImp TO ApiDB;
GRANT REFERENCES ON sres.Taxon TO ApiDB;

INSERT INTO core.DatabaseInfo
   (database_id, name, description, modification_date, user_read, user_write,
    group_read, group_write, other_read, other_write, row_user_id,
    row_group_id, row_project_id, row_alg_invocation_id)
SELECT core.databaseinfo_sq.nextval, 'ApiDB',
       'Application-specific data for the ApiDB websites', sysdate,
       1, 1, 1, 1, 1, 1, 1, 1, p.project_id, 0
FROM dual, (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p
WHERE lower('ApiDB') NOT IN (SELECT lower(name) FROM core.DatabaseInfo);

-- tuningManager needs there to be a index named "apidb.blastp_text_ix"
--  (because OracleText needs it)
CREATE INDEX apidb.blastp_text_ix
ON core.tableinfo(superclass_table_id, table_id, database_id);


exit
