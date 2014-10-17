CREATE TABLE ApiDB.Reaction (
  REACTION_ID                   NUMBER(12)    NOT NULL,
  SOURCE_ID                     VARCHAR(50)   NOT NULL,
  DESCRIPTION                   VARCHAR(255),
  EQUATION                    	VARCHAR(255),  
  MODIFICATION_DATE             DATE,
  USER_READ                     NUMBER(1),
  USER_WRITE                    NUMBER(1),
  GROUP_READ                    NUMBER(10),
  GROUP_WRITE                   NUMBER(1),
  OTHER_READ                    NUMBER(1),
  OTHER_WRITE                   NUMBER(1),
  ROW_USER_ID                   NUMBER(12),
  ROW_GROUP_ID                  NUMBER(4),
  ROW_PROJECT_ID        	NUMBER(4),
  ROW_ALG_INVOCATION_ID		NUMBER(12),
  PRIMARY KEY (REACTION_ID)
);


CREATE TABLE ApiDB.ReactionRelationship (
  REACTION_RELATIONSHIP_ID       NUMBER(12)  NOT NULL,
  REACTION_ID               	 NUMBER(10)  NOT NULL,
  PATHWAY_RELATIONSHIP_ID 	 NUMBER(12)  NOT NULL,
  PATHWAY_ID 		  	 NUMBER(12),
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
  PRIMARY KEY (REACTION_RELATIONSHIP_ID),
  FOREIGN KEY (REACTION_ID) REFERENCES ApiDB.Reaction (REACTION_ID),
  FOREIGN KEY (PATHWAY_RELATIONSHIP_ID) REFERENCES SRes.PathwayRelationship (PATHWAY_RELATIONSHIP_ID)
);


CREATE TABLE ApiDB.ReactionXRefs (
  REACTION_XREFS_ID   		 NUMBER(12)  NOT NULL,
  REACTION_ID               	 NUMBER(10)  NOT NULL,
  ASSOCIATED_REACTION_ID 	 NUMBER(10)  NOT NULL,
  EXTERNAL_DATABASE_RELEASE_ID   NUMBER(10)  NOT NULL,
  MODIFICATION_DATE       	 DATE,
  USER_READ               	 NUMBER(1),
  USER_WRITE              	 NUMBER(1),
  GROUP_READ              	 NUMBER(1),
  GROUP_WRITE             	 NUMBER(1),
  OTHER_READ              	 NUMBER(1),
  OTHER_WRITE             	 NUMBER(1),
  ROW_USER_ID            	 NUMBER(12),
  ROW_GROUP_ID            	 NUMBER(4),
  ROW_PROJECT_ID          	 NUMBER(4),
  ROW_ALG_INVOCATION_ID   	 NUMBER(12),
  PRIMARY KEY (REACTION_XREFS_ID),
  FOREIGN KEY (REACTION_ID) REFERENCES ApiDB.Reaction (REACTION_ID),
  FOREIGN KEY (ASSOCIATED_REACTION_ID) REFERENCES ApiDB.Reaction (REACTION_ID)
);


CREATE SEQUENCE ApiDB.Reaction_SQ;
CREATE SEQUENCE ApiDB.ReactionRelationship_SQ;
CREATE SEQUENCE ApiDB.ReactionXRefs_SQ;


GRANT SELECT ON ApiDB.Reaction TO gus_r;
GRANT SELECT ON ApiDB.ReactionRelationship TO gus_r;
GRANT SELECT ON ApiDB.ReactionXRefs TO gus_r;


GRANT INSERT, SELECT, UPDATE, DELETE ON ApiDB.Reaction TO gus_w;
GRANT INSERT, SELECT, UPDATE, DELETE ON ApiDB.ReactionRelationship TO gus_w;
GRANT INSERT, SELECT, UPDATE, DELETE ON ApiDB.ReactionXRefs TO gus_w;


GRANT SELECT ON ApiDB.Reaction_SQ TO gus_w;
GRANT SELECT ON ApiDB.ReactionRelationship_SQ TO gus_w;
GRANT SELECT ON ApiDB.ReactionXRefs_SQ TO gus_w;





INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable,
     modification_date, user_read, user_write, group_read, group_write,
     other_read, other_write, row_user_id, row_group_id, row_project_id,
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'Reaction',
       'Standard', 'REACTION_ID',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'Reaction' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable,
     modification_date, user_read, user_write, group_read, group_write,
     other_read, other_write, row_user_id, row_group_id, row_project_id,
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'ReactionRelationship',
       'Standard', 'REACTION_RELATIONSHIP_ID',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'ReactionRelationship' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable,
     modification_date, user_read, user_write, group_read, group_write,
     other_read, other_write, row_user_id, row_group_id, row_project_id,
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'ReactionXRefs',
       'Standard', 'REACTION_XREFS_ID',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'ReactionXRefs' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);


exit;
