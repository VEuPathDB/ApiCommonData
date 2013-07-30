
----------------------------------------------------------------------------

grant references on SRes.ExternalDatabaseRelease to ApiDB;

create table ApiDB.ProfileSet (
 profile_set_id        NUMBER(10),
 external_database_release_id NUMBER(10),
 name                  VARCHAR2(150),
 description           VARCHAR2(2500),
 x_axis_descrip        varchar2(400),
 y_axis_descrip        varchar2(400),
 x_axis_units          varchar2(100),
 y_axis_units          varchar2(100),
 source_id_type        VARCHAR(200),
 element_count         NUMBER(3),
 is_logged             NUMBER(1),
 base                  NUMBER(2),
 MODIFICATION_DATE     DATE,
 USER_READ             NUMBER(1),
 USER_WRITE            NUMBER(1),
 GROUP_READ            NUMBER(1),
 GROUP_WRITE           NUMBER(1),
 OTHER_READ            NUMBER(1),
 OTHER_WRITE           NUMBER(1),
 ROW_USER_ID           NUMBER(12),
 ROW_GROUP_ID          NUMBER(3),
 ROW_PROJECT_ID        NUMBER(4),
 ROW_ALG_INVOCATION_ID NUMBER(12),
 FOREIGN KEY (external_database_release_id) REFERENCES SRes.ExternalDatabaseRelease,
 PRIMARY KEY (profile_set_id)
);

CREATE INDEX apiDB.profileset_name_idx ON apiDB.ProfileSet (name, profile_set_id);

create sequence ApiDB.ProfileSet_sq;

GRANT insert, select, update, delete ON ApiDB.ProfileSet TO gus_w;
GRANT select ON ApiDB.ProfileSet TO gus_r;
GRANT select ON ApiDB.ProfileSet_sq TO gus_w;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'ProfileSet',
       'Standard', 'profile_set_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'ProfileSet' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);

----------------------------------------------------------------------------


grant references on dots.nafeatureimp to ApiDB;

create table ApiDB.Profile (
 profile_id            NUMBER(10),
 profile_set_id        NUMBER(10),
 subject_table_id      NUMBER(10),
 subject_row_id        NUMBER(10),
 source_id             VARCHAR2(60),
 profile_as_string     CLOB,
 no_evidence_of_expr   NUMBER(1),
 equiv_min             NUMBER(2),
 equiv_max             NUMBER(2),
 ind_ratio             FLOAT(126),
 max_percentile        FLOAT(126),
 min_expression        FLOAT(126),
 max_expression        FLOAT(126),
 min_log_ratio         FLOAT(126),
 max_log_ratio         FLOAT(126),
 ind_norm_by_med       FLOAT(126),
 time_of_max_expr      VARCHAR(40),
 time_of_min_expr      VARCHAR(40),
 MODIFICATION_DATE     DATE,
 USER_READ             NUMBER(1),
 USER_WRITE            NUMBER(1),
 GROUP_READ            NUMBER(1),
 GROUP_WRITE           NUMBER(1),
 OTHER_READ            NUMBER(1),
 OTHER_WRITE           NUMBER(1),
 ROW_USER_ID           NUMBER(12),
 ROW_GROUP_ID          NUMBER(3),
 ROW_PROJECT_ID        NUMBER(4),
 ROW_ALG_INVOCATION_ID NUMBER(12),
 FOREIGN KEY (profile_set_id) REFERENCES ApiDB.ProfileSet,
 PRIMARY KEY (profile_id)
);

CREATE INDEX apiDB.profile_sourceid_ind ON apiDB.Profile(source_id);
CREATE INDEX apiDB.profile_psi_ind ON apiDB.Profile(profile_set_id, profile_id);
CREATE INDEX apiDB.p_mod_ix ON apiDB.Profile (modification_date, profile_id);

GRANT INSERT, SELECT, UPDATE, DELETE ON ApiDB.Profile TO gus_w;
GRANT SELECT ON ApiDB.Profile TO gus_r;

CREATE sequence ApiDB.Profile_sq;

GRANT SELECT ON ApiDB.Profile_sq TO gus_w;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'Profile',
       'Standard', 'profile_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'Profile' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);

----------------------------------------------------------------------------

create table ApiDB.ProfileElementName (
 profile_element_name_id NUMBER(10),
 profile_set_id          NUMBER(10),
 name                    VARCHAR2(100),
 element_order           NUMBER(2),
 modification_date       DATE,
 user_read               NUMBER(1),
 user_write              NUMBER(1),
 group_read              NUMBER(1),
 group_write             NUMBER(1),
 other_read              NUMBER(1),
 other_write             NUMBER(1),
 row_user_id             NUMBER(12),
 row_group_id            NUMBER(3),
 row_project_id          NUMBER(4),
 row_alg_invocation_id   NUMBER(12),
 FOREIGN KEY (profile_set_id) REFERENCES ApiDB.ProfileSet,
 PRIMARY KEY (profile_element_name_id)
);

create index ApiDB.PROFELENAME_NAME_IND on ApiDB.ProfileElementName(name, profile_set_id, element_order);
create index ApiDB.PROFILEELEMENTNAME_revix0 on APIDB.ProfileElementName (profile_set_id, profile_element_name_id);

create sequence ApiDB.ProfileElementName_sq;

GRANT insert, select, update, delete ON ApiDB.ProfileElementName TO gus_w;
GRANT select ON ApiDB.ProfileElementName TO gus_r;
GRANT select ON ApiDB.ProfileElementName_sq TO gus_w;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'ProfileElementName',
       'Standard', 'profile_element_name_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'ProfileElementName' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);

----------------------------------------------------------------------------


create table ApiDB.ProfileElement (
 profile_element_id    NUMBER(10),
 profile_id            NUMBER(10),
 profile_element_name_id NUMBER(10),
 value                 FLOAT(126),
 modification_date     DATE,
 user_read             NUMBER(1),
 user_write            NUMBER(1),
 group_read            NUMBER(1),
 group_write           NUMBER(1),
 other_read            NUMBER(1),
 other_write           NUMBER(1),
 row_user_id           NUMBER(12),
 row_group_id          NUMBER(3),
 row_project_id        NUMBER(4),
 row_alg_invocation_id NUMBER(12),
 FOREIGN KEY (profile_id) REFERENCES ApiDB.Profile,
 FOREIGN KEY (profile_element_name_id) REFERENCES ApiDB.ProfileElementName,
 PRIMARY KEY (profile_element_id)
);

CREATE INDEX apiDB.pe_profile_element_name_ind
ON apiDB.ProfileElement(profile_element_name_id, profile_id, value);

CREATE INDEX apiDB.pe_profid_ind
ON apiDB.ProfileElement(profile_id, profile_element_name_id, value);

CREATE INDEX apiDB.pe_mod_ix
ON apiDB.profileelement (modification_date, profile_element_id);

CREATE SEQUENCE apiDB.ProfileElement_sq;

GRANT insert, select, update, delete ON ApiDB.ProfileElement TO gus_w;
GRANT select ON ApiDB.ProfileElement TO gus_r;
GRANT select ON ApiDB.ProfileElement_sq TO gus_w;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'ProfileElement',
       'Standard', 'profile_element_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'ProfileElement' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);

----------------------------------------------------------------------------

grant references on dots.nafeatureimp to ApiDB;

create table ApiDB.GeneProfileCorrelation (
 gene_profile_correlation_id NUMBER(10),
 gene_feature_id  NUMBER(10),
 first_profile_set_id   NUMBER(10),
 second_profile_set_id   NUMBER(10),
 score                   float,
 modification_date       DATE,
 user_read               NUMBER(1),
 user_write              NUMBER(1),
 group_read              NUMBER(1),
 group_write             NUMBER(1),
 other_read              NUMBER(1),
 other_write             NUMBER(1),
 row_user_id             NUMBER(12),
 row_group_id            NUMBER(3),
 row_project_id          NUMBER(4),
 row_alg_invocation_id   NUMBER(12),
 FOREIGN KEY (gene_feature_id) REFERENCES DoTS.NaFeatureImp (na_feature_id),
 FOREIGN KEY (first_profile_set_id) REFERENCES ApiDB.ProfileSet (profile_set_id),
 FOREIGN KEY (second_profile_set_id) REFERENCES ApiDB.ProfileSet (profile_set_id),
 PRIMARY KEY (gene_profile_correlation_id)
);

create sequence ApiDB.GeneProfileCorrelation_sq;

GRANT insert, select, update, delete ON ApiDB.GeneProfileCorrelation TO gus_w;
GRANT select ON ApiDB.GeneProfileCorrelation TO gus_r;
GRANT select ON ApiDB.GeneProfileCorrelation_sq TO gus_w;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'GeneProfileCorrelation',
       'Standard', 'gene_profile_correlation_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'GeneProfileCorrelation' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);

create index ApiDB.GeneProfileCorrelation_revix1 on ApiDB.GeneProfileCorrelation (second_profile_set_id, gene_profile_correlation_id);
create index ApiDB.GeneProfileCorrelation_revix2 on ApiDB.GeneProfileCorrelation (first_profile_set_id, gene_profile_correlation_id);
create index ApiDB.GeneProfileCorrelation_revix3 on ApiDB.GeneProfileCorrelation (gene_feature_id, gene_profile_correlation_id);

----------------------------------------------------------------------------

exit;
