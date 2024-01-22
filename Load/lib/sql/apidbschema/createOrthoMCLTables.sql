CREATE TABLE apidb.OrthoGroups (
 protein_id                  VARCHAR2(25) NOT NULL,
 core_peripheral_residual     VARCHAR2(1) NOT NULL,
 ortho_group_id               VARCHAR2(12) NOT NULL,
 modification_date            DATE NOT NULL,
 user_read                    NUMBER(1) NOT NULL,
 user_write                   NUMBER(1) NOT NULL,
 group_read                   NUMBER(1) NOT NULL,
 group_write                  NUMBER(1) NOT NULL,
 other_read                   NUMBER(1) NOT NULL,
 other_write                  NUMBER(1) NOT NULL,
 row_user_id                  NUMBER(12) NOT NULL,
 row_group_id                 NUMBER(3) NOT NULL,
 row_project_id               NUMBER(4) NOT NULL,
 row_alg_invocation_id        NUMBER(12) NOT NULL,
 PRIMARY KEY (protein_id)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.OrthoGroups TO gus_w;
GRANT SELECT ON apidb.OrthoGroups TO gus_r;
CREATE SEQUENCE apidb.OrthoGroups_sq;
GRANT SELECT ON apidb.OrthoGroups_sq TO gus_r;
GRANT SELECT ON apidb.OrthoGroups_sq TO gus_w;
INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'OrthoGroups',
       'Standard', 'PROTEIN_ID',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'orthogroups' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    where database_id = d.database_id);

CREATE TABLE apidb.OrthoGroupCoreStats (
 ortho_group_id               VARCHAR2(15) NOT NULL,
 min                          FLOAT,
 twentyfifth                  FLOAT,
 median                       FLOAT,
 seventyfifth                 FLOAT,
 max                          FLOAT,
 modification_date            DATE NOT NULL,
 user_read                    NUMBER(1) NOT NULL,
 user_write                   NUMBER(1) NOT NULL,
 group_read                   NUMBER(1) NOT NULL,
 group_write                  NUMBER(1) NOT NULL,
 other_read                   NUMBER(1) NOT NULL,
 other_write                  NUMBER(1) NOT NULL,
 row_user_id                  NUMBER(12) NOT NULL,
 row_group_id                 NUMBER(3) NOT NULL,
 row_project_id               NUMBER(4) NOT NULL,
 row_alg_invocation_id        NUMBER(12) NOT NULL,
 PRIMARY KEY (ortho_group_id)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.OrthoGroupCoreStats TO gus_w;
GRANT SELECT ON apidb.OrthoGroupCoreStats TO gus_r;
CREATE SEQUENCE apidb.OrthoGroupCoreStats_sq;
GRANT SELECT ON apidb.OrthoGroupCoreStats_sq TO gus_r;
GRANT SELECT ON apidb.OrthoGroupCoreStats_sq TO gus_w;
INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'OrthoGroupCoreStats',
       'Standard', 'ORTHO_GROUP_ID',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'orthogroupcorestats' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    where database_id = d.database_id);

CREATE TABLE apidb.OrthoGroupCorePeripheralStats (
 ortho_group_id               VARCHAR2(15) NOT NULL,
 min                          FLOAT,
 twentyfifth                  FLOAT,
 median                       FLOAT,
 seventyfifth                 FLOAT,
 max                          FLOAT,
 modification_date            DATE NOT NULL,
 user_read                    NUMBER(1) NOT NULL,
 user_write                   NUMBER(1) NOT NULL,
 group_read                   NUMBER(1) NOT NULL,
 group_write                  NUMBER(1) NOT NULL,
 other_read                   NUMBER(1) NOT NULL,
 other_write                  NUMBER(1) NOT NULL,
 row_user_id                  NUMBER(12) NOT NULL,
 row_group_id                 NUMBER(3) NOT NULL,
 row_project_id               NUMBER(4) NOT NULL,
 row_alg_invocation_id        NUMBER(12) NOT NULL,
 PRIMARY KEY (ortho_group_id)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.OrthoGroupCorePeripheralStats TO gus_w;
GRANT SELECT ON apidb.OrthoGroupCorePeripheralStats TO gus_r;
CREATE SEQUENCE apidb.OrthoGroupCorePeripheralStats_sq;
GRANT SELECT ON apidb.OrthoGroupCorePeripheralStats_sq TO gus_r;
GRANT SELECT ON apidb.OrthoGroupCorePeripheralStats_sq TO gus_w;
INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'OrthoGroupCorePeripheralStats',
       'Standard', 'ORTHO_GROUP_ID',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'orthogroupcoreperipheralstats' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    where database_id = d.database_id);

CREATE TABLE apidb.OrthoGroupResidualStats (
 ortho_group_id               VARCHAR2(15) NOT NULL,
 min                          FLOAT,
 twentyfifth                  FLOAT,
 median                       FLOAT,
 seventyfifth                 FLOAT,
 max                          FLOAT,
 modification_date            DATE NOT NULL,
 user_read                    NUMBER(1) NOT NULL,
 user_write                   NUMBER(1) NOT NULL,
 group_read                   NUMBER(1) NOT NULL,
 group_write                  NUMBER(1) NOT NULL,
 other_read                   NUMBER(1) NOT NULL,
 other_write                  NUMBER(1) NOT NULL,
 row_user_id                  NUMBER(12) NOT NULL,
 row_group_id                 NUMBER(3) NOT NULL,
 row_project_id               NUMBER(4) NOT NULL,
 row_alg_invocation_id        NUMBER(12) NOT NULL,
 PRIMARY KEY (ortho_group_id)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.OrthoGroupResidualStats TO gus_w;
GRANT SELECT ON apidb.OrthoGroupResidualStats TO gus_r;
CREATE SEQUENCE apidb.OrthoGroupResidualStats_sq;
GRANT SELECT ON apidb.OrthoGroupResidualStats_sq TO gus_r;
GRANT SELECT ON apidb.OrthoGroupResidualStats_sq TO gus_w;
INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'OrthoGroupResidualStats',
       'Standard', 'ORTHO_GROUP_ID',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'orthogroupresidualstats' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    where database_id = d.database_id);

exit;
