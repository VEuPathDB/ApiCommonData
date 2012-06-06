CREATE TABLE ApiDB.Pathway (
  PATHWAY_ID                    NUMBER(12)    NOT NULL,
  NAME                          VARCHAR(150)  NOT NULL,
  DESCRIPTION                   VARCHAR(255),
  EXTERNAL_DATABASE_RELEASE_ID  NUMBER(10)    NOT NULL,
  SOURCE_ID                     VARCHAR(50)   NOT NULL,
  URL                           VARCHAR(255)  NOT NULL,
  MODIFICATION_DATE             DATE,
  USER_READ                     NUMBER(1) ,
  USER_WRITE                    NUMBER(1) ,
  GROUP_READ                    NUMBER(10),
  GROUP_WRITE                   NUMBER(1) ,
  OTHER_READ                    NUMBER(1) ,
  OTHER_WRITE                   NUMBER(1) ,
  ROW_USER_ID                   NUMBER(12),
  ROW_GROUP_ID                  NUMBER(4) ,
  ROW_PROJECT_ID                NUMBER(4) ,
  ROW_ALG_INVOCATION_ID         NUMBER(12),
  PRIMARY KEY (PATHWAY_ID)
);



CREATE TABLE ApiDB.PathwayNode (
  PATHWAY_NODE_ID	  NUMBER(12)   NOT NULL,
  DISPLAY_LABEL           VARCHAR(50)  NOT NULL,
  PATHWAY_NODE_TYPE_ID    NUMBER(10)   NOT NULL,
  TABLE_ID                NUMBER(5),
  ROW_ID                  NUMBER(12),
  PARENT_ID 		  NUMBER(12),
  GLYPH_TYPE_ID           NUMBER(10),
  X                       NUMBER(10),
  Y                       NUMBER(10),
  WIDTH                   NUMBER(10),
  HEIGHT                  NUMBER(10),
  MODIFICATION_DATE       DATE,
  USER_READ               NUMBER(1),
  USER_WRITE              NUMBER(1),
  GROUP_READ              NUMBER(1),
  GROUP_WRITE             NUMBER(1),
  OTHER_READ              NUMBER(1),
  OTHER_WRITE             NUMBER(1), 
  ROW_USER_ID             NUMBER(12),
  ROW_GROUP_ID            NUMBER(4),
  ROW_PROJECT_ID          NUMBER(4),
  ROW_ALG_INVOCATION_ID   NUMBER(12),
  PRIMARY KEY (PATHWAY_NODE_ID)
);


CREATE TABLE ApiDB.PathwayRelationship (
  PATHWAY_RELATIONSHIP_ID NUMBER(12)   NOT NULL,
  PATHWAY_ID              NUMBER(12)   NOT NULL,
  RELATIONSHIP_TYPE_ID    NUMBER(10)   NOT NULL,
  RELATIONSHIP_SUBTYPE_ID NUMBER(10)   NOT NULL,
  NODE_ID                 NUMBER(12)   NOT NULL,
  ASSOCIATED_NODE_ID      NUMBER(12)   NOT NULL, 
  MODIFICATION_DATE       DATE,
  USER_READ               NUMBER(1),
  USER_WRITE              NUMBER(1),
  GROUP_READ              NUMBER(1),
  GROUP_WRITE             NUMBER(1),
  OTHER_READ              NUMBER(1),
  OTHER_WRITE             NUMBER(1),
  ROW_USER_ID             NUMBER(12),
  ROW_GROUP_ID            NUMBER(4),
  ROW_PROJECT_ID          NUMBER(4),
  ROW_ALG_INVOCATION_ID   NUMBER(12),
  PRIMARY KEY (PATHWAY_RELATIONSHIP_ID),
  FOREIGN KEY (PATHWAY_ID) REFERENCES ApiDB.Pathway (PATHWAY_ID),
  FOREIGN KEY (NODE_ID) REFERENCES ApiDB.PathwayNode (PATHWAY_NODE_ID),
  FOREIGN KEY (ASSOCIATED_NODE_ID) REFERENCES ApiDB.PathwayNode (PATHWAY_NODE_ID)
);

CREATE SEQUENCE ApiDB.Pathway_SEQ;
CREATE SEQUENCE ApiDB.PathwayNode_SEQ;
CREATE SEQUENCE ApiDB.PathwayRelationship_SEQ;





GRANT SELECT ON ApiDB.Pathway TO gus_r;
GRANT SELECT ON ApiDB.PathwayNode TO gus_r;
GRANT SELECT ON ApiDB.PathwayRelationship TO gus_r;

GRANT INSERT, SELECT, UPDATE, DELETE ON ApiDB.Pathway TO gus_w;
GRANT INSERT, SELECT, UPDATE, DELETE ON ApiDB.PathwayNode TO gus_w;
GRANT INSERT, SELECT, UPDATE, DELETE ON ApiDB.PathwayRelationship TO gus_w;

GRANT SELECT ON ApiDB.Pathway_SEQ TO gus_w;
GRANT SELECT ON ApiDB.PathwayNode_SEQ TO gus_w;
GRANT SELECT ON ApiDB.PathwayRelationship_SEQ TO gus_w;





CREATE INDEX apidb.pathway_idx ON ApiDB.Pathway (PATHWAY_ID,NAME);
CREATE INDEX apidb.pathwayNode_idx ON ApiDB.PathwayNode (PATHWAY_NODE_ID,DISPLAY_LABEL);
CREATE INDEX apidb.pathwayRelationship_idx ON ApiDB.PathwayRelationship (PATHWAY_RELATIONSHIP_ID,PATHWAY_ID);




INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable,
     modification_date, user_read, user_write, group_read, group_write,
     other_read, other_write, row_user_id, row_group_id, row_project_id,
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'Pathway',
       'Standard', 'PATHWAY_ID',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'Pathway' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);



INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable,
     modification_date, user_read, user_write, group_read, group_write,
     other_read, other_write, row_user_id, row_group_id, row_project_id,
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'PathwayNode',
       'Standard', 'PATHWAY_NODE_ID',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'PathwayNode' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);



INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable,
     modification_date, user_read, user_write, group_read, group_write,
     other_read, other_write, row_user_id, row_group_id, row_project_id,
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'PathwayRelationship',
       'Standard', 'PATHWAY_RELATIONSHIP_ID',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'PathwayRelationship' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);


exit;
