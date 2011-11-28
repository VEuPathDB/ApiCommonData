
----------------------------------------------------------------------------


create table ApiDB.ProfileSet (
 profile_set_id        NUMERIC(10),
 external_database_release_id NUMERIC(10),
 name                  character varying(100),
 description           character varying(2500),
 x_axis_descrip        character varying(400),
 y_axis_descrip        character varying(400),
 x_axis_units          character varying(100),
 y_axis_units          character varying(100),
 source_id_type        VARCHAR(200),
 element_count         NUMERIC(3),
 MODIFICATION_DATE     timestamp,
 USER_READ             NUMERIC(1),
 USER_WRITE            NUMERIC(1),
 GROUP_READ            NUMERIC(1),
 GROUP_WRITE           NUMERIC(1),
 OTHER_READ            NUMERIC(1),
 OTHER_WRITE           NUMERIC(1),
 ROW_USER_ID           NUMERIC(12),
 ROW_GROUP_ID          NUMERIC(3),
 ROW_PROJECT_ID        NUMERIC(4),
 ROW_ALG_INVOCATION_ID NUMERIC(12),
 FOREIGN KEY (external_database_release_id) REFERENCES SRes.ExternalDatabaseRelease,
 PRIMARY KEY (profile_set_id)
);

CREATE INDEX profileset_name_idx ON apiDB.ProfileSet (name, profile_set_id);

create sequence ApiDB.ProfileSet_sq;


INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT nextval('core.tableinfo_sq'), 'ProfileSet',
       'Standard', 'profile_set_id',
       (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb'), 0, 0, NULL, NULL, 
       1,current_timestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo), 0
WHERE lower('ProfileSet') NOT IN (SELECT lower(name) FROM core.TableInfo
        WHERE database_id = (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb'));


----------------------------------------------------------------------------



create table ApiDB.Profile (
 profile_id            NUMERIC(10),
 profile_set_id        NUMERIC(10),
 subject_table_id      NUMERIC(10),
 subject_row_id        NUMERIC(10),
 source_id             character varying(60),
 profile_as_string     character varying(4000),
 no_evidence_of_expr   NUMERIC(1),
 equiv_min             NUMERIC(2),
 equiv_max             NUMERIC(2),
 ind_ratio             FLOAT(40),
 max_percentile        FLOAT(40),
 min_expression        FLOAT(40),
 max_expression        FLOAT(40),
 min_log_ratio         FLOAT(40),
 max_log_ratio         FLOAT(40),
 ind_norm_by_med       FLOAT(40),
 time_of_max_expr      VARCHAR(40),
 time_of_min_expr      VARCHAR(40),
 MODIFICATION_DATE     timestamp,
 USER_READ             NUMERIC(1),
 USER_WRITE            NUMERIC(1),
 GROUP_READ            NUMERIC(1),
 GROUP_WRITE           NUMERIC(1),
 OTHER_READ            NUMERIC(1),
 OTHER_WRITE           NUMERIC(1),
 ROW_USER_ID           NUMERIC(12),
 ROW_GROUP_ID          NUMERIC(3),
 ROW_PROJECT_ID        NUMERIC(4),
 ROW_ALG_INVOCATION_ID NUMERIC(12),
 FOREIGN KEY (profile_set_id) REFERENCES ApiDB.ProfileSet,
 PRIMARY KEY (profile_id)
);

CREATE INDEX profile_sourceid_ind ON apiDB.Profile(source_id);
CREATE INDEX profile_psi_ind ON apiDB.Profile(profile_set_id, profile_id);


CREATE sequence ApiDB.Profile_sq;


INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT nextval('core.tableinfo_sq'), 'Profile',
       'Standard', 'profile_id',
       (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb'), 0, 0, NULL, NULL, 
       1,current_timestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo), 0
WHERE lower('Profile') NOT IN (SELECT lower(name) FROM core.TableInfo
        WHERE database_id = (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb'));

----------------------------------------------------------------------------


create table ApiDB.ProfileElement (
 profile_element_id    NUMERIC(10),
 profile_id            NUMERIC(10),
 value                 FLOAT(40),
 element_order         NUMERIC(3),
 modification_date     timestamp,
 user_read             NUMERIC(1),
 user_write            NUMERIC(1),
 group_read            NUMERIC(1),
 group_write           NUMERIC(1),
 other_read            NUMERIC(1),
 other_write           NUMERIC(1),
 row_user_id           NUMERIC(12),
 row_group_id          NUMERIC(3),
 row_project_id        NUMERIC(4),
 row_alg_invocation_id NUMERIC(12),
 FOREIGN KEY (profile_id) REFERENCES ApiDB.Profile,
 PRIMARY KEY (profile_element_id)
);

CREATE INDEX pe_element_order_ind
ON apiDB.ProfileElement(element_order, profile_element_id);

CREATE INDEX pe_profid_ind
ON apiDB.ProfileElement(profile_id, profile_element_id);

CREATE SEQUENCE apiDB.ProfileElement_sq;


INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT nextval('core.tableinfo_sq'), 'ProfileElement',
       'Standard', 'profile_element_id',
       (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb'), 0, 0, NULL, NULL, 
       1,current_timestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo), 0
WHERE lower('ProfileElement') NOT IN (SELECT lower(name) FROM core.TableInfo
        WHERE database_id = (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb'));


----------------------------------------------------------------------------


create table ApiDB.ProfileElementName (
 profile_element_name_id NUMERIC(10),
 profile_set_id          NUMERIC(10),
 name                    character varying(40),
 element_order           NUMERIC(2),
 modification_date       timestamp,
 user_read               NUMERIC(1),
 user_write              NUMERIC(1),
 group_read              NUMERIC(1),
 group_write             NUMERIC(1),
 other_read              NUMERIC(1),
 other_write             NUMERIC(1),
 row_user_id             NUMERIC(12),
 row_group_id            NUMERIC(3),
 row_project_id          NUMERIC(4),
 row_alg_invocation_id   NUMERIC(12),
 FOREIGN KEY (profile_set_id) REFERENCES ApiDB.ProfileSet,
 PRIMARY KEY (profile_element_name_id)
);

create index PROFELENAME_NAME_IND on ApiDB.ProfileElementName(name, profile_set_id, element_order);
create index PROFILEELEMENTNAME_revix0 on APIDB.ProfileElementName (profile_set_id, profile_element_name_id);

create sequence ApiDB.ProfileElementName_sq;



INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT nextval('core.tableinfo_sq'), 'ProfileElementName',
       'Standard', 'profile_element_id',
       (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb'), 0, 0, NULL, NULL, 
       1,current_timestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo), 0
WHERE lower('ProfileElementName') NOT IN (SELECT lower(name) FROM core.TableInfo
        WHERE database_id = (SELECT database_id FROM 
        core.DatabaseInfo WHERE lower(name) = 'apidb'));


----------------------------------------------------------------------------


create table ApiDB.GeneProfileCorrelation (
 gene_profile_correlation_id NUMERIC(10),
 gene_feature_id  NUMERIC(10),
 first_profile_set_id   NUMERIC(10),
 second_profile_set_id   NUMERIC(10),
 score                   float,
 modification_date       timestamp,
 user_read               NUMERIC(1),
 user_write              NUMERIC(1),
 group_read              NUMERIC(1),
 group_write             NUMERIC(1),
 other_read              NUMERIC(1),
 other_write             NUMERIC(1),
 row_user_id             NUMERIC(12),
 row_group_id            NUMERIC(3),
 row_project_id          NUMERIC(4),
 row_alg_invocation_id   NUMERIC(12),
 FOREIGN KEY (gene_feature_id) REFERENCES DoTS.NaFeatureImp (na_feature_id),
 FOREIGN KEY (first_profile_set_id) REFERENCES ApiDB.ProfileSet (profile_set_id),
 FOREIGN KEY (second_profile_set_id) REFERENCES ApiDB.ProfileSet (profile_set_id),
 PRIMARY KEY (gene_profile_correlation_id)
);

create sequence ApiDB.GeneProfileCorrelation_sq;


INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT nextval('core.tableinfo_sq'), 'GeneProfileCorrelation',
       'Standard', 'gene_profile_correlation_id',
       (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb'), 0, 0, NULL, NULL, 
       1,current_timestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo), 0
WHERE lower('GeneProfileCorrelation') NOT IN (SELECT lower(name) FROM core.TableInfo
        WHERE database_id = (SELECT database_id FROM 
        core.DatabaseInfo WHERE lower(name) = 'apidb'));

create index GeneProfileCorrelation_revix1 on ApiDB.GeneProfileCorrelation (second_profile_set_id, gene_profile_correlation_id);
create index GeneProfileCorrelation_revix2 on ApiDB.GeneProfileCorrelation (first_profile_set_id, gene_profile_correlation_id);
create index GeneProfileCorrelation_revix3 on ApiDB.GeneProfileCorrelation (gene_feature_id, gene_profile_correlation_id);

----------------------------------------------------------------------------
