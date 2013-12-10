CREATE TABLE ApiDB.NetworkContext (
  NETWORK_CONTEXT_ID             NUMBER(3)    NOT NULL,
  NAME                           VARCHAR(50)  NOT NULL,
  DESCRIPTION                    VARCHAR(250),
  ANATOMY_ID                     NUMBER(10),
  BIOLOGICAL_PROCESS_ID          NUMBER(10),
  DEVELOPMENTAL_STAGE_START_ID   NUMBER(10),
  DEVELOPMENTAL_STAGE_END_ID     NUMBER(10),
  MODIFICATION_DATE              DATE,
  USER_READ                      NUMBER(1),
  USER_WRITE                     NUMBER(1),
  GROUP_READ                     NUMBER(1),
  GROUP_WRITE                    NUMBER(1),
  OTHER_READ                     NUMBER(1),
  OTHER_WRITE                    NUMBER(1),
  ROW_USER_ID                    NUMBER(12),
  ROW_GROUP_ID                   NUMBER(3),
  ROW_PROJECT_ID                 NUMBER(4),
  ROW_ALG_INVOCATION_ID          NUMBER(12),
  PRIMARY KEY (NETWORK_CONTEXT_ID)
);


CREATE TABLE ApiDB.Network (
  NETWORK_ID               NUMBER(10)   NOT NULL,
  NAME                     VARCHAR(100) NOT NULL,
  DESCRIPTION              VARCHAR(250),
  MODIFICATION_DATE        DATE,
  USER_READ                NUMBER(1),
  USER_WRITE               NUMBER(1),
  GROUP_READ               NUMBER(1),
  GROUP_WRITE              NUMBER(1),
  OTHER_READ               NUMBER(1),
  OTHER_WRITE              NUMBER(1),
  ROW_USER_ID              NUMBER(12),
  ROW_GROUP_ID             NUMBER(3),
  ROW_PROJECT_ID           NUMBER(4),
  ROW_ALG_INVOCATION_ID    NUMBER(12),
  PRIMARY KEY (NETWORK_ID)
);



CREATE TABLE ApiDB.NetworkNode (
  NETWORK_NODE_ID                NUMBER(10)  NOT NULL,	
  NODE_TYPE_ID                   NUMBER(10)  NOT NULL,
  TABLE_ID                       NUMBER(5),
  ROW_ID                         NUMBER(12),
  DISPLAY_LABEL                  VARCHAR(25),
  IDENTIFIER                           VARCHAR(50),
  MODIFICATION_DATE              DATE,
  USER_READ                      NUMBER(1),
  USER_WRITE                     NUMBER(1),
  GROUP_READ                     NUMBER(1),
  GROUP_WRITE                    NUMBER(1),
  OTHER_READ                     NUMBER(1),
  OTHER_WRITE                    NUMBER(1),
  ROW_USER_ID                    NUMBER(12),
  ROW_GROUP_ID                   NUMBER(3),
  ROW_PROJECT_ID                 NUMBER(4),
  ROW_ALG_INVOCATION_ID          NUMBER(12),
  PRIMARY KEY (NETWORK_NODE_ID)
);



CREATE TABLE ApiDB.NetworkRelationship (
  NETWORK_RELATIONSHIP_ID        NUMBER(12)  NOT NULL,
  NODE_ID                        NUMBER(10)  NOT NULL,
  ASSOCIATED_NODE_ID             NUMBER(10)  NOT NULL,
  WEIGHT                         FLOAT,
  MODIFICATION_DATE              DATE,
  USER_READ                      NUMBER(1),
  USER_WRITE                     NUMBER(1),
  GROUP_READ                     NUMBER(1),
  GROUP_WRITE                    NUMBER(1),
  OTHER_READ                     NUMBER(1),
  OTHER_WRITE                    NUMBER(1),
  ROW_USER_ID                    NUMBER(12),
  ROW_GROUP_ID                   NUMBER(3),
  ROW_PROJECT_ID                 NUMBER(4),
  ROW_ALG_INVOCATION_ID          NUMBER(12),
  PRIMARY KEY (NETWORK_RELATIONSHIP_ID),
  FOREIGN KEY (NODE_ID) REFERENCES ApiDB.NetworkNode (NETWORK_NODE_ID),
  FOREIGN KEY (ASSOCIATED_NODE_ID) REFERENCES ApiDB.NetworkNode (NETWORK_NODE_ID)
);

CREATE INDEX ApiDB.nr_mod_ix ON ApiDB.NetworkRelationship (modification_date, network_relationship_id);


CREATE TABLE ApiDB.NetworkRelationshipType(
  NETWORK_RELATIONSHIP_TYPE_ID   NUMBER(11)   NOT NULL,
  RELATIONSHIP_TYPE_ID           NUMBER(10)   NOT NULL,
  DISPLAY_NAME                   VARCHAR(100) NOT NULL,
  MODIFICATION_DATE              DATE,
  USER_READ                      NUMBER(1),
  USER_WRITE                     NUMBER(1),
  GROUP_READ                     NUMBER(1),
  GROUP_WRITE                    NUMBER(1),
  OTHER_READ                     NUMBER(1),
  OTHER_WRITE                    NUMBER(1),
  ROW_USER_ID                    NUMBER(12),
  ROW_GROUP_ID                   NUMBER(3),
  ROW_PROJECT_ID                 NUMBER(4),
  ROW_ALG_INVOCATION_ID          NUMBER(12),
  PRIMARY KEY (NETWORK_RELATIONSHIP_TYPE_ID)
);


CREATE TABLE ApiDB.NetworkRelContext(
  NETWORK_REL_CONTEXT_ID         NUMBER(12)  NOT NULL,
  NETWORK_RELATIONSHIP_ID        NUMBER(12)  NOT NULL,
  NETWORK_RELATIONSHIP_TYPE_ID   NUMBER(11)  NOT NULL,
  NETWORK_CONTEXT_ID             NUMBER(3)   NOT NULL,
  WEIGHT                         FLOAT,
  SOURCE_NODE                    NUMBER(1),
  MODIFICATION_DATE              DATE,
  USER_READ                      NUMBER(1),
  USER_WRITE                     NUMBER(1),
  GROUP_READ                     NUMBER(1),
  GROUP_WRITE                    NUMBER(1),
  OTHER_READ                     NUMBER(1),
  OTHER_WRITE                    NUMBER(1),
  ROW_USER_ID                    NUMBER(12),
  ROW_GROUP_ID                   NUMBER(3),
  ROW_PROJECT_ID                 NUMBER(4),
  ROW_ALG_INVOCATION_ID          NUMBER(12),
  FOREIGN KEY (NETWORK_RELATIONSHIP_ID) REFERENCES ApiDB.NetworkRelationship (NETWORK_RELATIONSHIP_ID),
  FOREIGN KEY (NETWORK_RELATIONSHIP_TYPE_ID) REFERENCES ApiDB.NetworkRelationshipType (NETWORK_RELATIONSHIP_TYPE_ID),
  FOREIGN KEY (NETWORK_CONTEXT_ID) REFERENCES ApiDB.NetworkContext (NETWORK_CONTEXT_ID),
  PRIMARY KEY (NETWORK_REL_CONTEXT_ID)
);

CREATE INDEX ApiDB.nrc_mod_ix ON ApiDB.NetworkRelContext (modification_date, network_rel_context_id);


CREATE TABLE ApiDB.NetworkRelContextLink(
  NETWORK_RC_LINK_ID             NUMBER(12)  NOT NULL,
  NETWORK_ID                     NUMBER(10)  NOT NULL,
  NETWORK_REL_CONTEXT_ID         NUMBER(12)  NOT NULL,
  MODIFICATION_DATE              DATE,
  USER_READ                      NUMBER(1),
  USER_WRITE                     NUMBER(1),
  GROUP_READ                     NUMBER(1),
  GROUP_WRITE                    NUMBER(1),
  OTHER_READ                     NUMBER(1),
  OTHER_WRITE                    NUMBER(1),
  ROW_USER_ID                    NUMBER(12),
  ROW_GROUP_ID                   NUMBER(3),
  ROW_PROJECT_ID                 NUMBER(4),
  ROW_ALG_INVOCATION_ID          NUMBER(12),
  PRIMARY KEY (NETWORK_RC_LINK_ID)
);

CREATE INDEX ApiDB.nrcl_mod_ix ON ApiDB.NetworkRelContextLink (modification_date, network_rc_link_id);


CREATE SEQUENCE ApiDB.NetworkContext_sq;
CREATE SEQUENCE ApiDB.Network_sq;
CREATE SEQUENCE ApiDB.NetworkNode_sq;
CREATE SEQUENCE ApiDB.NetworkRelationship_sq;
CREATE SEQUENCE ApiDB.NetworkRelationshipType_sq;
CREATE SEQUENCE ApiDB.NetworkRelContext_sq;
CREATE SEQUENCE ApiDB.NetworkRelContextLink_sq;



GRANT SELECT ON ApiDB.NetworkContext TO gus_r;
GRANT SELECT ON ApiDB.Network TO gus_r;
GRANT SELECT ON ApiDB.NetworkNode TO gus_r;
GRANT SELECT ON ApiDB.NetworkRelationship TO gus_r;
GRANT SELECT ON ApiDB.NetworkRelationshipType TO gus_r;
GRANT SELECT ON ApiDB.NetworkRelContext TO gus_r;
GRANT SELECT ON ApiDB.NetworkRelContextLink TO gus_r;

GRANT INSERT, SELECT, UPDATE, DELETE ON ApiDB.NetworkContext TO gus_w;
GRANT INSERT, SELECT, UPDATE, DELETE ON ApiDB.Network TO gus_w;
GRANT INSERT, SELECT, UPDATE, DELETE ON ApiDB.NetworkNode TO gus_w;
GRANT INSERT, SELECT, UPDATE, DELETE ON ApiDB.NetworkRelationship TO gus_w;
GRANT INSERT, SELECT, UPDATE, DELETE ON ApiDB.NetworkRelationshipType TO gus_w;
GRANT INSERT, SELECT, UPDATE, DELETE ON ApiDB.NetworkRelContext TO gus_w;
GRANT INSERT, SELECT, UPDATE, DELETE ON ApiDB.NetworkRelContextLink TO gus_w;

GRANT SELECT ON ApiDB.NetworkContext_sq TO gus_w;
GRANT SELECT ON ApiDB.Network_sq TO gus_w;
GRANT SELECT ON ApiDB.NetworkNode_sq TO gus_w;
GRANT SELECT ON ApiDB.NetworkRelationship_sq TO gus_w;
GRANT SELECT ON ApiDB.NetworkRelationshipType_sq TO gus_w;
GRANT SELECT ON ApiDB.NetworkRelContext_sq TO gus_w;
GRANT SELECT ON ApiDB.NetworkRelContextLink_sq TO gus_w;



INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'NetworkContext',
       'Standard', 'profile_set_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'NetworkContext' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);


INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'Network',
       'Standard', 'profile_set_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'Network' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);


INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'NetworkNode',
       'Standard', 'profile_set_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'NetworkNode' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);


INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'NetworkRelationship',
       'Standard', 'profile_set_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'NetworkRelationship' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);


INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'NetworkRelationshipType',
       'Standard', 'profile_set_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'NetworkRelationshipType' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);


INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'NetworkRelContext',
       'Standard', 'profile_set_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'NetworkRelContext' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);


INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'NetworkRelContextLink',
       'Standard', 'profile_set_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'NetworkRelContextLink' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);

exit;
