CREATE TABLE hmdb.compounds(                                                                                                                                                                                
    ID              NUMBER(12)      NOT NULL,
    NAME            VARCHAR(1000),
    SOURCE          VARCHAR(32)     NOT NULL,
    PARENT_ID       NUMBER(12),
    HMDB_ACCESSION  VARCHAR(30)     NOT NULL,
    STATUS          VARCHAR(1),
    DEFINITION      CLOB,
    MODIFICATION_DATE             DATE,
    USER_READ                     NUMBER(1),
    USER_WRITE                    NUMBER(1),
    GROUP_READ                    NUMBER(10),
    GROUP_WRITE                   NUMBER(1),
    OTHER_READ                    NUMBER(1),
    OTHER_WRITE                   NUMBER(1),
    ROW_USER_ID                   NUMBER(12),
    ROW_GROUP_ID                  NUMBER(4),
    ROW_PROJECT_ID                NUMBER(4),
    ROW_ALG_INVOCATION_ID         NUMBER(12),
    PRIMARY KEY (ID),
    FOREIGN KEY (PARENT_ID) REFERENCES hmdb.compounds(ID)
);
CREATE INDEX hmdb.c_revix0 ON hmdb.compounds(parent_id) TABLESPACE indx;

CREATE TABLE hmdb.chemical_data (
  ID                            NUMBER(12)    NOT NULL,
  COMPOUND_ID                   NUMBER(12)    NOT NULL,
  CHEMICAL_DATA                 VARCHAR(255)  NOT NULL,
  SOURCE                        VARCHAR(255)  NOT NULL,
  TYPE                          VARCHAR(255)  NOT NULL,
  MODIFICATION_DATE             DATE,
  USER_READ                     NUMBER(1),
  USER_WRITE                    NUMBER(1),
  GROUP_READ                    NUMBER(10),
  GROUP_WRITE                   NUMBER(1),
  OTHER_READ                    NUMBER(1),
  OTHER_WRITE                   NUMBER(1),
  ROW_USER_ID                   NUMBER(12),
  ROW_GROUP_ID                  NUMBER(4),
  ROW_PROJECT_ID        	    NUMBER(4),
  ROW_ALG_INVOCATION_ID		    NUMBER(12),
  PRIMARY KEY (ID),
  FOREIGN KEY (COMPOUND_ID) REFERENCES hmdb.compounds(ID)
);
CREATE INDEX hmdb.cd_revix0 ON hmdb.chemical_data(compound_id) TABLESPACE indx;

CREATE TABLE hmdb.database_accession (
    ID                NUMBER(12)      NOT NULL,
    COMPOUND_ID       NUMBER(12)      NOT NULL,
    ACCESSION_NUMBER  VARCHAR(255)    NOT NULL,
    TYPE              VARCHAR(32)     NOT NULL,
    SOURCE            VARCHAR(32)     NOT NULL,
    MODIFICATION_DATE             DATE,
    USER_READ                     NUMBER(1),
    USER_WRITE                    NUMBER(1),
    GROUP_READ                    NUMBER(10),
    GROUP_WRITE                   NUMBER(1),
    OTHER_READ                    NUMBER(1),
    OTHER_WRITE                   NUMBER(1),
    ROW_USER_ID                   NUMBER(12),
    ROW_GROUP_ID                  NUMBER(4),
    ROW_PROJECT_ID                NUMBER(4),
    ROW_ALG_INVOCATION_ID         NUMBER(12),
    PRIMARY KEY (ID),
    FOREIGN KEY (COMPOUND_ID) REFERENCES hmdb.compounds(ID)
);
CREATE INDEX hmdb.da_revix0 ON hmdb.database_accession(compound_id) TABLESPACE indx;

CREATE TABLE hmdb.names (
    ID              NUMBER(12)      NOT NULL,
    COMPOUND_ID     NUMBER(12)      NOT NULL,
    NAME            VARCHAR(1000)    NOT NULL,
    TYPE            VARCHAR(32)     NOT NULL,
    SOURCE          VARCHAR(32)     NOT NULL,
    MODIFICATION_DATE             DATE,
    USER_READ                     NUMBER(1),
    USER_WRITE                    NUMBER(1),
    GROUP_READ                    NUMBER(10),
    GROUP_WRITE                   NUMBER(1),
    OTHER_READ                    NUMBER(1),
    OTHER_WRITE                   NUMBER(1),
    ROW_USER_ID                   NUMBER(12),
    ROW_GROUP_ID                  NUMBER(4),
    ROW_PROJECT_ID                NUMBER(4),
    ROW_ALG_INVOCATION_ID         NUMBER(12),
    PRIMARY KEY (ID),
    FOREIGN KEY (COMPOUND_ID) REFERENCES hmdb.compounds(ID)
);
CREATE INDEX hmdb.names_revix0 ON hmdb.names(compound_id) TABLESPACE indx;

CREATE TABLE hmdb.structures (
    ID              NUMBER(12)      NOT NULL,
    COMPOUND_ID     NUMBER(12)      NOT NULL,
    STRUCTURE       CLOB            NOT NULL,
    TYPE            VARCHAR(255)    NOT NULL,
    DIMENSION       VARCHAR(255)    NOT NULL,
    MODIFICATION_DATE             DATE,                                                                                                               
    USER_READ                     NUMBER(1),
    USER_WRITE                    NUMBER(1),
    GROUP_READ                    NUMBER(10),
    GROUP_WRITE                   NUMBER(1),
    OTHER_READ                    NUMBER(1),
    OTHER_WRITE                   NUMBER(1),
    ROW_USER_ID                   NUMBER(12),
    ROW_GROUP_ID                  NUMBER(4),
    ROW_PROJECT_ID                NUMBER(4),
    ROW_ALG_INVOCATION_ID         NUMBER(12),
    PRIMARY KEY (ID),
    FOREIGN KEY (COMPOUND_ID) REFERENCES hmdb.compounds(ID)
);
CREATE INDEX hmdb.s_revix0 ON hmdb.structures(compound_id) TABLESPACE indx;

CREATE TABLE hmdb.default_structures (
    ID              NUMBER(12)      NOT NULL,
    STRUCTURE_ID    NUMBER(12)      NOT NULL,
    MODIFICATION_DATE             DATE,
    USER_READ                     NUMBER(1),
    USER_WRITE                    NUMBER(1),
    GROUP_READ                    NUMBER(10),
    GROUP_WRITE                   NUMBER(1),
    OTHER_READ                    NUMBER(1),
    OTHER_WRITE                   NUMBER(1),
    ROW_USER_ID                   NUMBER(12),
    ROW_GROUP_ID                  NUMBER(4),
    ROW_PROJECT_ID        	    NUMBER(4),
    ROW_ALG_INVOCATION_ID		    NUMBER(12),
    PRIMARY KEY (ID),
    FOREIGN KEY (STRUCTURE_ID) REFERENCES hmdb.structures(ID)
);
CREATE INDEX hmdb.ds_revix0 ON hmdb.default_structures(structure_id) TABLESPACE indx;

CREATE TABLE hmdb.autogen_structures (
    ID              NUMBER(12)      NOT NULL,
    STRUCTURE_ID    NUMBER(12)      NOT NULL,
    MODIFICATION_DATE             DATE,
    USER_READ                     NUMBER(1),
    USER_WRITE                    NUMBER(1),
    GROUP_READ                    NUMBER(10),
    GROUP_WRITE                   NUMBER(1),
    OTHER_READ                    NUMBER(1),
    OTHER_WRITE                   NUMBER(1),
    ROW_USER_ID                   NUMBER(12),
    ROW_GROUP_ID                  NUMBER(4),
    ROW_PROJECT_ID        	    NUMBER(4),
    ROW_ALG_INVOCATION_ID		    NUMBER(12),
    PRIMARY KEY (ID),
    FOREIGN KEY (STRUCTURE_ID) REFERENCES hmdb.structures(ID)
);
CREATE INDEX hmdb.as_revix0 ON hmdb.autogen_structures(structure_id) TABLESPACE indx;

CREATE SEQUENCE hmdb.chemical_data_SQ;
CREATE SEQUENCE hmdb.compounds_SQ;
CREATE SEQUENCE hmdb.database_accession_SQ;
CREATE SEQUENCE hmdb.names_SQ;
CREATE SEQUENCE hmdb.structures_SQ;
CREATE SEQUENCE hmdb.default_structures_SQ;
CREATE SEQUENCE hmdb.autogen_structures_SQ;

GRANT SELECT ON hmdb.chemical_data TO gus_r;
GRANT SELECT ON hmdb.compounds TO gus_r;
GRANT SELECT ON hmdb.database_accession TO gus_r;
GRANT SELECT ON hmdb.names TO gus_r;
GRANT SELECT ON hmdb.structures TO gus_r;
GRANT SELECT ON hmdb.default_structures TO gus_r;
GRANT SELECT ON hmdb.autogen_structures TO gus_r;

GRANT INSERT, SELECT, UPDATE, DELETE ON hmdb.chemical_data TO gus_w;
GRANT INSERT, SELECT, UPDATE, DELETE ON hmdb.compounds TO gus_w;
GRANT INSERT, SELECT, UPDATE, DELETE ON hmdb.database_accession TO gus_w;
GRANT INSERT, SELECT, UPDATE, DELETE ON hmdb.names TO gus_w;
GRANT INSERT, SELECT, UPDATE, DELETE ON hmdb.structures TO gus_w;
GRANT INSERT, SELECT, UPDATE, DELETE ON hmdb.default_structures TO gus_w;
GRANT INSERT, SELECT, UPDATE, DELETE ON hmdb.autogen_structures TO gus_w;

GRANT SELECT ON hmdb.chemical_data_SQ TO gus_r;
GRANT SELECT ON hmdb.compounds_SQ TO gus_r;
GRANT SELECT ON hmdb.database_accession_SQ TO gus_r;
GRANT SELECT ON hmdb.names_SQ TO gus_r;
GRANT SELECT ON hmdb.structures_SQ TO gus_r;
GRANT SELECT ON hmdb.default_structures_SQ TO gus_r;
GRANT SELECT ON hmdb.autogen_structures_SQ TO gus_r;

GRANT SELECT ON hmdb.chemical_data_SQ TO gus_w;
GRANT SELECT ON hmdb.compounds_SQ TO gus_w;
GRANT SELECT ON hmdb.database_accession_SQ TO gus_w;
GRANT SELECT ON hmdb.names_SQ TO gus_w;
GRANT SELECT ON hmdb.structures_SQ TO gus_w;
GRANT SELECT ON hmdb.default_structures_SQ TO gus_w;
GRANT SELECT ON hmdb.autogen_structures_SQ TO gus_w;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable,
     modification_date, user_read, user_write, group_read, group_write,
     other_read, other_write, row_user_id, row_group_id, row_project_id,
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'chemical_data',
       'Standard', 'ID',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'hmdb') d
WHERE 'chemical_data' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);
INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable,
     modification_date, user_read, user_write, group_read, group_write,
     other_read, other_write, row_user_id, row_group_id, row_project_id,
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'compounds',
       'Standard', 'ID',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'hmdb') d
WHERE 'compounds' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);
INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable,
     modification_date, user_read, user_write, group_read, group_write,
     other_read, other_write, row_user_id, row_group_id, row_project_id,
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'database_accession',
       'Standard', 'ID',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'hmdb') d
WHERE 'database_accession' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);
INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable,
     modification_date, user_read, user_write, group_read, group_write,
     other_read, other_write, row_user_id, row_group_id, row_project_id,
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'names',
       'Standard', 'ID',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'hmdb') d
WHERE 'names' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);
INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable,
     modification_date, user_read, user_write, group_read, group_write,
     other_read, other_write, row_user_id, row_group_id, row_project_id,
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'structures',
       'Standard', 'ID',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'hmdb') d
WHERE 'structures' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);
INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable,
     modification_date, user_read, user_write, group_read, group_write,
     other_read, other_write, row_user_id, row_group_id, row_project_id,
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'default_structures',
       'Standard', 'ID',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'hmdb') d
WHERE 'default_structures' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable,
     modification_date, user_read, user_write, group_read, group_write,
     other_read, other_write, row_user_id, row_group_id, row_project_id,
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'autogen_structures',
       'Standard', 'ID',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'hmdb') d
WHERE 'autogen_structures' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);

exit;
