-- deprecated; have the DBAs do this
-- CREATE USER ApidbTuning
-- IDENTIFIED BY "<password>"   -- deprecated
-- QUOTA UNLIMITED ON users 
-- QUOTA UNLIMITED ON gus
-- QUOTA UNLIMITED ON indx
-- DEFAULT TABLESPACE users
-- TEMPORARY TABLESPACE temp;

CREATE SCHEMA apidbtuning;


-- GRANT GUS_R TO ApidbTuning;
-- GRANT GUS_W TO ApidbTuning;


-- GRANT REFERENCES ON dots.GeneFeature TO ApidbTuning;
-- GRANT REFERENCES ON dots.NaFeature TO ApidbTuning;
-- GRANT REFERENCES ON dots.NaFeatureNaGene TO ApidbTuning;
-- GRANT REFERENCES ON dots.AaSequenceImp TO ApidbTuning;
-- GRANT REFERENCES ON sres.Taxon TO ApidbTuning;

-- GRANTs required for CTXSYS
-- GRANT CONNECT, RESOURCE, CTXAPP, GUS_W to ApiDBTuning;

-- tuningManager needs there to be a index named "ApidbTuning.blastp_text_ix"
--  (because OracleText needs it)
CREATE INDEX blastp_text_ix ON core.tableinfo(superclass_table_id, table_id, database_id);


INSERT INTO core.DatabaseInfo
   (database_id, name, description, modification_date, user_read, user_write,
    group_read, group_write, other_read, other_write, row_user_id,
    row_group_id, row_project_id, row_alg_invocation_id)
SELECT NEXTVAL('core.databaseinfo_sq'), 'ApidbTuning',
       'schema for tables created by tuning manager', localtimestamp,
       1, 1, 1, 1, 1, 1, 1, 1, p.project_id, 0
FROM (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p
WHERE lower('ApidbTuning') NOT IN (SELECT lower(name) FROM core.DatabaseInfo);

-- alter user ApidbTuning quota unlimited on indx;

--------------------------------------------------------------------------------
--
-- create empty Sanger tuning tables, so they can be referenced even in
-- instances for which we don't run the Sanger feed
--
CREATE TABLE apidbTuning.AnnotationChange0000
 (
  gene        varchar(60),
  mrnaid      varchar(80),
  change      varchar(400),
  change_date date,
  name        varchar(60),
  product     varchar(800)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON apidbtuning.annotationchange0000 TO PUBLIC;

-- Posgtres doesn't have synonyms. Convert them to views instead
CREATE OR REPLACE VIEW apidbtuning.annotationchange AS SELECT * FROM apidbtuning.annotationchange0000;

CREATE TABLE apidbTuning.ChangedGeneProduct0000
  (
   gene    varchar(80),
   product varchar(800),
   name    varchar(60)
  );

GRANT INSERT, SELECT, UPDATE, DELETE ON apidbtuning.changedgeneproduct0000 TO PUBLIC;

-- Posgtres doesn't have synonyms. Convert them to views instead
CREATE OR REPLACE VIEW apidbtuning.changedgeneproduct AS SELECT * FROM apidbtuning.changedgeneproduct0000;

--------------------------------------------------------------------------------
CREATE TABLE apidbTuning.StudyIdDatasetId0000 (
  study_stable_id varchar(200),
  dataset_id      varchar(15)
  );

GRANT SELECT ON apidbTuning.StudyIdDatasetId0000 TO PUBLIC;

-- Posgtres doesn't have synonyms. Convert them to views instead
-- create or replace synonym apidbTuning.StudyIdDatasetId for apidbTuning.StudyIdDatasetId0000;
CREATE OR REPLACE VIEW apidbtuning.studyiddatasetid AS SELECT * FROM apidbtuning.studyiddatasetid0000;

--------------------------------------------------------------------------------