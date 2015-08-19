CREATE USER chebi
IDENTIFIED BY VALUES '36811EDD93CB4A00'  -- encoding of standard password
QUOTA UNLIMITED ON users 
QUOTA UNLIMITED ON gus
DEFAULT TABLESPACE users
TEMPORARY TABLESPACE temp;

GRANT GUS_R TO chebi;
GRANT GUS_W TO chebi;
GRANT CREATE VIEW TO chebi;
GRANT CREATE MATERIALIZED VIEW TO chebi;
GRANT CREATE TABLE TO chebi;
GRANT CREATE SYNONYM TO chebi;
GRANT CREATE SESSION TO chebi;
GRANT CREATE ANY INDEX TO chebi;
GRANT CREATE TRIGGER TO chebi;
GRANT CREATE ANY TRIGGER TO chebi;


INSERT INTO core.DatabaseInfo
   (database_id, name, description, modification_date, user_read, user_write,
    group_read, group_write, other_read, other_write, row_user_id,
    row_group_id, row_project_id, row_alg_invocation_id)
SELECT core.databaseinfo_sq.nextval, 'chEBI',
       'Application-specific data for the chEBI data', sysdate,
       1, 1, 1, 1, 1, 1, 1, 1, p.project_id, 0
FROM dual, (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p
WHERE lower('chEBI') NOT IN (SELECT lower(name) FROM core.DatabaseInfo);


-- GRANTs required for CTXSYS
GRANT CONNECT, RESOURCE, CTXAPP, GUS_W to chebi;

GRANT REFERENCES ON chEBI.Compounds to Results;

create table Results.CompoundMassSpec
  (
    compound_mass_spec_id number(12) not null,
    PROTOCOL_APP_NODE_ID   number(10) not null,
    compound_id            number(12) not null,
    value                  float(126),
    isotopomer            varchar2(100),
    MODIFICATION_DATE     date not null,
    USER_READ             number(1) not null,
    USER_WRITE            number(1) not null,
    GROUP_READ            number(1) not null,
    GROUP_WRITE           number(1) not null,
    OTHER_READ            number(1) not null,
    OTHER_WRITE           number(1) not null,
    ROW_USER_ID           number(12) not null,
    ROW_GROUP_ID          number(4) not null,
    ROW_PROJECT_ID        number(4) not null,
    ROW_ALG_INVOCATION_ID number(12) not null,
    foreign key (PROTOCOL_APP_NODE_ID) references STUDY.PROTOCOLAPPNODE,
    foreign key (compound_ID) references chEBI.compound (id),
    primary key (REPORTER_INTENSITY_ID)
  );


create sequence RESULTS.CompoundMassSpec_SQ;

GRANT insert, select, update, delete ON  RESULTS.CompoundMassSpec TO gus_w;
GRANT select ON RESULTS.CompoundMassSpec TO gus_r;
GRANT select ON RESULTS.CompoundMassSpec_sq TO gus_w;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     ROW_ALG_INVOCATION_ID)
select CORE.TABLEINFO_SQ.NEXTVAL, 'CompoundMassSpec',
       'Standard', 'compound_mass_spec_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (select DATABASE_ID from CORE.DATABASEINFO where name = 'Results') D
WHERE 'compoundmassspec' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    where DATABASE_ID = D.DATABASE_ID);





exit
