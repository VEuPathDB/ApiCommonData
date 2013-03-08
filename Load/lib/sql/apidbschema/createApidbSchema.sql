CREATE USER ApiDB
IDENTIFIED BY VALUES '8362207F0DC5BC14'  -- encoding of standard password
QUOTA UNLIMITED ON users 
QUOTA UNLIMITED ON gus
DEFAULT TABLESPACE users
TEMPORARY TABLESPACE temp;

GRANT GUS_R TO ApiDB;
GRANT GUS_W TO ApiDB;
GRANT CREATE VIEW TO ApiDB;
GRANT CREATE MATERIALIZED VIEW TO ApiDB;
GRANT CREATE TABLE TO ApiDB;
GRANT CREATE SYNONYM TO ApiDB;
GRANT CREATE SESSION TO ApiDB;
GRANT CREATE ANY INDEX TO ApiDB;
GRANT CREATE TRIGGER TO ApiDB;
GRANT CREATE ANY TRIGGER TO ApiDB;

GRANT REFERENCES ON core.TableInfo to ApiDB;
GRANT REFERENCES ON dots.AaSequenceImp TO ApiDB;
GRANT REFERENCES ON dots.BlatAlignmentQuality to ApiDB;
GRANT REFERENCES ON dots.GeneFeature TO ApiDB;
GRANT REFERENCES ON dots.NaFeatureNaGene TO ApiDB;
GRANT REFERENCES ON dots.NaFeature TO ApiDB;
GRANT REFERENCES ON dots.NaSequenceImp to ApiDB;
GRANT REFERENCES ON sres.ExternalDatabaseRelease to ApiDB;
GRANT REFERENCES ON sres.Taxon TO ApiDB;
GRANT REFERENCES ON study.Biomaterial TO ApiDB;
GRANT REFERENCES ON study.BiomaterialImp TO ApiDB;

-- must be GRANTed directly (not just through a role such as GUS_R) for use in PL/SQL functions
GRANT SELECT ON core.ProjectInfo to ApiDB;
GRANT SELECT ON sres.TaxonName to ApiDB;
GRANT SELECT, UPDATE ON dots.SeqVariation to ApiDB;

INSERT INTO core.DatabaseInfo
   (database_id, name, description, modification_date, user_read, user_write,
    group_read, group_write, other_read, other_write, row_user_id,
    row_group_id, row_project_id, row_alg_invocation_id)
SELECT core.databaseinfo_sq.nextval, 'ApiDB',
       'Application-specific data for the ApiDB websites', sysdate,
       1, 1, 1, 1, 1, 1, 1, 1, p.project_id, 0
FROM dual, (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p
WHERE lower('ApiDB') NOT IN (SELECT lower(name) FROM core.DatabaseInfo);

-- GRANTs required for CTXSYS
GRANT CONNECT, RESOURCE, CTXAPP, GUS_W to apidb;

exit
