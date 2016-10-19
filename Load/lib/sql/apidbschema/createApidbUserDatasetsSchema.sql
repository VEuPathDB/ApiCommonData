CREATE USER ApiDBUserDatasets
IDENTIFIED BY VALUES '8362207F0DC5BC14'  -- encoding of standard password
QUOTA UNLIMITED ON users 
QUOTA UNLIMITED ON gus
QUOTA UNLIMITED ON indx
DEFAULT TABLESPACE users
TEMPORARY TABLESPACE temp;

GRANT GUS_R TO ApidbUserDatasets;
GRANT GUS_W TO ApidbUserDatasets;
GRANT CREATE VIEW TO Apidbuserdatasets;
GRANT CREATE MATERIALIZED VIEW TO Apidbuserdatasets;
GRANT CREATE TABLE TO Apidbuserdatasets;
GRANT CREATE SYNONYM TO Apidbuserdatasets;
GRANT CREATE SESSION TO Apidbuserdatasets;
GRANT CREATE ANY INDEX TO Apidbuserdatasets;
GRANT CREATE TRIGGER TO Apidbuserdatasets;
GRANT CREATE ANY TRIGGER TO Apidbuserdatasets;

GRANT REFERENCES ON core.TableInfo to Apidbuserdatasets;
GRANT REFERENCES ON dots.AaSequenceImp TO Apidbuserdatasets;
GRANT REFERENCES ON dots.GeneFeature TO Apidbuserdatasets;
GRANT REFERENCES ON dots.NaFeatureNaGene TO Apidbuserdatasets;
GRANT REFERENCES ON dots.NaFeature TO Apidbuserdatasets;
GRANT REFERENCES ON dots.NaSequenceImp to Apidbuserdatasets;
GRANT REFERENCES ON sres.ExternalDatabaseRelease to Apidbuserdatasets;
GRANT REFERENCES ON sres.Taxon TO Apidbuserdatasets;
GRANT REFERENCES ON study.protocolappnode TO Apidbuserdatasets;

GRANT REFERENCES ON sres.PathwayRelationship TO Apidbuserdatasets;
GRANT REFERENCES ON sres.Pathway TO Apidbuserdatasets;

GRANT references ON dots.nafeatureimp TO apidbuserdatasets;
GRANT references ON DoTS.ChromosomeElementFeature TO Apidbuserdatasets;
GRANT references ON Sres.OntologyTerm TO Apidbuserdatasets;
GRANT REFERENCES ON sres.ExternalDatabase TO apidbuserdatasets;
GRANT REFERENCES ON core.AlgorithmInvocation TO Apidbuserdatasets;



-- must be GRANTed directly (not just through a role such as GUS_R) for use in PL/SQL functions
GRANT SELECT ON core.ProjectInfo to Apidbuserdatasets;
GRANT SELECT ON sres.TaxonName to Apidbuserdatasets;
GRANT SELECT ON sres.Taxon to Apidbuserdatasets;
GRANT SELECT, DELETE ON dots.NaFeatureImp TO PUBLIC;

INSERT INTO core.DatabaseInfo
   (database_id, name, description, modification_date, user_read, user_write,
    group_read, group_write, other_read, other_write, row_user_id,
    row_group_id, row_project_id, row_alg_invocation_id)
SELECT core.databaseinfo_sq.nextval, 'Apidbuserdatasets',
       'Installed User Datasets', sysdate,
       1, 1, 1, 1, 1, 1, 1, 1, p.project_id, 0
FROM dual, (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p
WHERE lower('Apidbuserdatasets') NOT IN (SELECT lower(name) FROM core.DatabaseInfo);

-- GRANTs required for CTXSYS
GRANT CONNECT, RESOURCE, CTXAPP, GUS_W to apidbuserdatasets;

exit
