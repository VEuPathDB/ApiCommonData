CREATE TABLE hmdb.compounds(                                                                                                                                                                                
    ID              NUMBER(12)      NOT NULL,
    NAME            VARCHAR(255)    NOT NULL,
    SOURCE          VARCHAR(32)     NOT NULL,
    PARENT_ID       NUMBER(12)      NOT NULL,
    HMDB_ACCESSION  VARCHAR(30)     NOT NULL,
    STATUS          VARCHAR(1)      NOT NULL,
    DEFINITION      VARCHAR(255),
    STAR            NUMBER(12)      NOT NULL,
    MODIFIED_ON     VARCHAR(32),
    CREATED_BY      VARCHAR(32), 
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
    PRIMARY KEY (ID)
);

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


CREATE TABLE hmdb.comments(
    ID          NUMBER(12)      NOT NULL,
    COMPOUND_ID NUMBER(12)      NOT NULL,
    TEXT        VARCHAR(255)    NOT NULL,
    CREATED_ON  DATE            NOT NULL,
    DATATYPE    VARCHAR(80),
    DATATYPE_ID NUMBER(12)      NOT NULL,
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
CREATE INDEX hmdb.co_revix0 ON hmdb.comments(compound_id) TABLESPACE indx;
    
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
    NAME            VARCHAR(255)    NOT NULL,
    TYPE            VARCHAR(32)     NOT NULL,
    SOURCE          VARCHAR(32)     NOT NULL,
    ADAPTED         VARCHAR(32)     NOT NULL,
    LANGUAGE        VARCHAR(32)     NOT NULL,
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

CREATE TABLE hmdb.ontology (
    ID          NUMBER(12)          NOT NULL,
    TITLE       VARCHAR(255)        NOT NULL,
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
    PRIMARY KEY (ID)
);

CREATE TABLE hmdb.reference (
    ID                  NUMBER(12)          NOT NULL,
    COMPOUND_ID         NUMBER(12)          NOT NULL,
    REFERENCE_ID        VARCHAR(60)         NOT NULL,
    REFERENCE_DB_NAME   VARCHAR(60)         NOT NULL,
    LOCATION_IN_REF     VARCHAR(90),
    REFERENCE_NAME      VARCHAR(512),
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
CREATE INDEX hmdb.ref_revix0 ON hmdb.reference(compound_id) TABLESPACE indx;

CREATE TABLE hmdb.vertice (
    ID              NUMBER(12)      NOT NULL,
    VERTICE_REF     VARCHAR(60)     NOT NULL,
    COMPOUND_ID     NUMBER(12),
    ONTOLOGY_ID     NUMBER(12)      NOT NULL,
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
    FOREIGN KEY (ONTOLOGY_ID) REFERENCES hmdb.ontology(ID),
    CONSTRAINT unique_ontology_ref UNIQUE (vertice_ref, ontology_id)
);
CREATE INDEX hmdb.ver_revix0 ON hmdb.vertice(ontology_id) TABLESPACE indx;

CREATE TABLE hmdb.relation (
    ID          NUMBER(12)          NOT NULL,
    TYPE        VARCHAR(255)        NOT NULL,
    INIT_ID     NUMBER(12)          NOT NULL,
    FINAL_ID    NUMBER(12)          NOT NULL,
    STATUS      VARCHAR(1)          NOT NULL,
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
    FOREIGN KEY (INIT_ID) REFERENCES hmdb.vertice(ID),
    FOREIGN KEY (FINAL_ID) REFERENCES hmdb.vertice(ID)
);
CREATE INDEX hmdb.rel_revix0 ON hmdb.relation(init_id) TABLESPACE indx;
CREATE INDEX hmdb.rel_revix1 ON hmdb.relation(final_id) TABLESPACE indx;

CREATE TABLE hmdb.structures (
    ID              NUMBER(12)      NOT NULL,
    COMPOUND_ID     NUMBER(12)      NOT NULL,
    STRUCTURE       VARCHAR(255)    NOT NULL,
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

CREATE TABLE hmdb.default_structures (
    ID              NUMBER(12)      NOT NULL,
    STRUCTURE_ID    NUMBER(12)      NOT NULL,
    PRIMARY KEY (ID),
    FOREIGN KEY (STRUCTURE_ID) REFERENCES hmdb.structures(ID)
);

CREATE TABLE hmdb.autogen_structures (
    ID              NUMBER(12)      NOT NULL,
    STRUCTURE_ID    NUMBER(12)      NOT NULL,
    PRIMARY KEY (ID),
    FOREIGN KEY (STRUCTURE_ID) REFERENCES hmdb.structures(ID)
);

CREATE SEQUENCE hmdb.chemical_data_SQ;
CREATE SEQUENCE hmdb.comments_SQ;
CREATE SEQUENCE hmdb.compounds_SQ;
CREATE SEQUENCE hmdb.database_accession_SQ;
CREATE SEQUENCE hmdb.names_SQ;
CREATE SEQUENCE hmdb.ontology_SQ;
CREATE SEQUENCE hmdb.reference_SQ;
CREATE SEQUENCE hmdb.relation_SQ;
CREATE SEQUENCE hmdb.vertice_SQ;
CREATE SEQUENCE hmdb.structures_SQ;
CREATE SEQUENCE hmdb.default_structures_SQ;
CREATE SEQUENCE hmdb.autogen_structures_SQ;

GRANT SELECT ON hmdb.chemical_data TO gus_r;
GRANT SELECT ON hmdb.comments TO gus_r;
GRANT SELECT ON hmdb.compounds TO gus_r;
GRANT SELECT ON hmdb.database_accession TO gus_r;
GRANT SELECT ON hmdb.names TO gus_r;
GRANT SELECT ON hmdb.ontology TO gus_r;
GRANT SELECT ON hmdb.reference TO gus_r;
GRANT SELECT ON hmdb.relation TO gus_r;
GRANT SELECT ON hmdb.vertice TO gus_r;
GRANT SELECT ON hmdb.structures TO gus_r;
GRANT SELECT ON hmdb.default_structures TO gus_r;
GRANT SELECT ON hmdb.autogen_structures TO gus_r;

GRANT INSERT, SELECT, UPDATE, DELETE ON hmdb.chemical_data TO gus_w;
GRANT INSERT, SELECT, UPDATE, DELETE ON hmdb.comments TO gus_w;
GRANT INSERT, SELECT, UPDATE, DELETE ON hmdb.compounds TO gus_w;
GRANT INSERT, SELECT, UPDATE, DELETE ON hmdb.database_accession TO gus_w;
GRANT INSERT, SELECT, UPDATE, DELETE ON hmdb.names TO gus_w;
GRANT INSERT, SELECT, UPDATE, DELETE ON hmdb.ontology TO gus_w;
GRANT INSERT, SELECT, UPDATE, DELETE ON hmdb.reference TO gus_w;
GRANT INSERT, SELECT, UPDATE, DELETE ON hmdb.relation TO gus_w;
GRANT INSERT, SELECT, UPDATE, DELETE ON hmdb.vertice TO gus_w;
GRANT INSERT, SELECT, UPDATE, DELETE ON hmdb.structures TO gus_w;
GRANT INSERT, SELECT, UPDATE, DELETE ON hmdb.default_structures TO gus_w;
GRANT INSERT, SELECT, UPDATE, DELETE ON hmdb.autogen_structures TO gus_w;

GRANT SELECT ON hmdb.chemical_data_SQ TO gus_r;
GRANT SELECT ON hmdb.comments_SQ TO gus_r;
GRANT SELECT ON hmdb.compounds_SQ TO gus_r;
GRANT SELECT ON hmdb.database_accession_SQ TO gus_r;
GRANT SELECT ON hmdb.names_SQ TO gus_r;
GRANT SELECT ON hmdb.ontology_SQ TO gus_r;
GRANT SELECT ON hmdb.reference_SQ TO gus_r;
GRANT SELECT ON hmdb.relation_SQ TO gus_r;
GRANT SELECT ON hmdb.vertice_SQ TO gus_r;
GRANT SELECT ON hmdb.structures_SQ TO gus_r;
GRANT SELECT ON hmdb.default_structures_SQ TO gus_r;
GRANT SELECT ON hmdb.autogen_structures_SQ TO gus_r;

GRANT SELECT ON hmdb.chemical_data_SQ TO gus_w;
GRANT SELECT ON hmdb.comments_SQ TO gus_w;
GRANT SELECT ON hmdb.compounds_SQ TO gus_w;
GRANT SELECT ON hmdb.database_accession_SQ TO gus_w;
GRANT SELECT ON hmdb.names_SQ TO gus_w;
GRANT SELECT ON hmdb.ontology_SQ TO gus_w;
GRANT SELECT ON hmdb.reference_SQ TO gus_w;
GRANT SELECT ON hmdb.relation_SQ TO gus_w;
GRANT SELECT ON hmdb.vertice_SQ TO gus_w;
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
SELECT core.tableinfo_sq.nextval, 'comments',
       'Standard', 'ID',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'hmdb') d
WHERE 'comments' NOT IN (SELECT name FROM core.TableInfo
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
SELECT core.tableinfo_sq.nextval, 'ontology',
       'Standard', 'ID',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'hmdb') d
WHERE 'ontology' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);
INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable,
     modification_date, user_read, user_write, group_read, group_write,
     other_read, other_write, row_user_id, row_group_id, row_project_id,
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'reference',
       'Standard', 'ID',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'hmdb') d
WHERE 'reference' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);
INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable,
     modification_date, user_read, user_write, group_read, group_write,
     other_read, other_write, row_user_id, row_group_id, row_project_id,
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'relation',
       'Standard', 'ID',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'hmdb') d
WHERE 'relation' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);
INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable,
     modification_date, user_read, user_write, group_read, group_write,
     other_read, other_write, row_user_id, row_group_id, row_project_id,
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'vertice',
       'Standard', 'ID',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'hmdb') d
WHERE 'vertice' NOT IN (SELECT name FROM core.TableInfo
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
