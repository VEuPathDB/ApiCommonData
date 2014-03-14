CREATE USER ApidbTuning
IDENTIFIED BY VALUES 'BBA8A2E0BB2D7072'   -- encoding of standard password
QUOTA UNLIMITED ON users 
QUOTA UNLIMITED ON gus
DEFAULT TABLESPACE users
TEMPORARY TABLESPACE temp;

GRANT GUS_R TO ApidbTuning;
GRANT GUS_W TO ApidbTuning;
GRANT CREATE VIEW TO ApidbTuning;
GRANT CREATE MATERIALIZED VIEW TO ApidbTuning;
GRANT CREATE TABLE TO ApidbTuning;
GRANT CREATE SYNONYM TO ApidbTuning;
GRANT CREATE SESSION TO ApidbTuning;
GRANT CREATE ANY INDEX TO ApidbTuning;
GRANT CREATE TRIGGER TO ApidbTuning;
GRANT CREATE ANY TRIGGER TO ApidbTuning;

GRANT REFERENCES ON dots.GeneFeature TO ApidbTuning;
GRANT REFERENCES ON dots.NaFeature TO ApidbTuning;
GRANT REFERENCES ON dots.NaFeatureNaGene TO ApidbTuning;
GRANT REFERENCES ON dots.AaSequenceImp TO ApidbTuning;
GRANT REFERENCES ON sres.Taxon TO ApidbTuning;

-- GRANTs required for CTXSYS
GRANT CONNECT, RESOURCE, CTXAPP, GUS_W to ApiDBTuning;

-- tuningManager needs there to be a index named "ApidbTuning.blastp_text_ix"
--  (because OracleText needs it)
CREATE INDEX ApidbTuning.blastp_text_ix
ON core.tableinfo(superclass_table_id, table_id, database_id);

-- create empty stubs of OrganismAttributes and OrganismTree, so we can 
-- make functions that reference them before the tuning manager has run
-- (for apidb.project_id())
create table ApidbTuning.OrganismAttributes0000 (
  project_id            varchar2(20),
  organism_name         varchar2(20),
  family_name_for_files varchar2(20)
);
grant select on ApidbTuning.OrganismAttributes0000 to public;
create synonym ApidbTuning.OrganismAttributes for ApidbTuning.OrganismAttributes0000;

create table ApidbTuning.OrganismTree0000 (
  project_id varchar2(20),
  term       varchar2(20)
);
grant select on ApidbTuning.OrganismTree0000 to public;
create synonym ApidbTuning.OrganismTree for ApidbTuning.OrganismTree0000;
exit
