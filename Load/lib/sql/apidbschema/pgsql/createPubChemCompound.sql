CREATE TABLE ApiDB.PubChemCompound (
 	pubchem_compound_id     NUMERIC(10),
 	compound_id             NUMERIC(10) NOT NULL,
 	MolecularWeight         NUMERIC(12),
 	MolecularFormula        VARCHAR(50),
 	IUPACName               VARCHAR(1000),
 	InChI                   VARCHAR(2000),
 	InChIKey                VARCHAR(100),
 	IsomericSmiles          VARCHAR(1000),
 	CanonicalSmiles         VARCHAR(1000),
 	MODIFICATION_DATE       DATE,
 	USER_READ               NUMERIC(1),
 	USER_WRITE              NUMERIC(1),
 	GROUP_READ              NUMERIC(1),
 	GROUP_WRITE             NUMERIC(1),
 	OTHER_READ              NUMERIC(1),
 	OTHER_WRITE             NUMERIC(1),
 	ROW_USER_ID             NUMERIC(12),
 	ROW_GROUP_ID            NUMERIC(3),
 	ROW_PROJECT_ID          NUMERIC(4),
 	ROW_ALG_INVOCATION_ID   NUMERIC(12),
 	PRIMARY KEY (pubchem_compound_id)
);


CREATE TABLE ApiDB.PubChemCompoundProperty (
 	pubchem_compound_property_id  NUMERIC(10),
 	pubchem_compound_id            NUMERIC(10) NOT NULL,
 	property                VARCHAR(20) NOT NULL,
 	value                   VARCHAR(3000) NOT NULL,
 	MODIFICATION_DATE       DATE,
 	USER_READ               NUMERIC(1),
 	USER_WRITE              NUMERIC(1),
 	GROUP_READ              NUMERIC(1),
 	GROUP_WRITE             NUMERIC(1),
 	OTHER_READ              NUMERIC(1),
 	OTHER_WRITE             NUMERIC(1),
 	ROW_USER_ID             NUMERIC(12),
 	ROW_GROUP_ID            NUMERIC(3),
 	ROW_PROJECT_ID          NUMERIC(4),
 	ROW_ALG_INVOCATION_ID   NUMERIC(12),
 	PRIMARY KEY (pubchem_compound_property_id),
	FOREIGN KEY (pubchem_compound_id) REFERENCES ApiDB.PubChemCompound (pubchem_compound_id)
);


CREATE INDEX pcc_mod_ix ON apidb.PubChemCompound (modification_date, pubchem_compound_id);
CREATE INDEX pccp_mod_ix ON apidb.PubChemCompoundProperty (modification_date, pubchem_compound_property_id);
CREATE INDEX pccp_revix ON apidb.PubChemCompoundProperty (pubchem_compound_id, pubchem_compound_property_id);


CREATE SEQUENCE apidb.PubChemCompound_sq;
CREATE SEQUENCE apidb.PubChemCompoundProperty_sq;


GRANT insert, select, update, delete ON apidb.PubChemCompound TO gus_w;
GRANT select ON apidb.PubChemCompound TO gus_r;
GRANT select ON apidb.PubChemCompound_sq TO gus_w;

GRANT insert, select, update, delete ON apidb.PubChemCompoundProperty TO gus_w;
GRANT select ON apidb.PubChemCompoundProperty TO gus_r;
GRANT select ON apidb.PubChemCompoundProperty_sq TO gus_w;


INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'PubChemCompound',
       'Standard', 'pubchem_compound_id',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'PubChemCompound' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'PubChemCompoundProperty',
       'Standard', 'pubchem_compound_property_id',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'PubChemCompoundProperty' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);
------------------------------------------------------------------------------
