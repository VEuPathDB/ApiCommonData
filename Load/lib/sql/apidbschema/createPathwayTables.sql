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
  FOREIGN KEY (NODE_ID) REFERENCES ApiDB.PathwayNode (NODE_ID),
  FOREIGN KEY (ASSOCIATED_NODE_ID) REFERENCES ApiDB.PathwayNode (NODE_ID)
);

CREATE SEQUENCE ApiDB.Pathway_SEQ;
CREATE SEQUENCE ApiDB.PathwayNode_SEQ;
CREATE SEQUENCE ApiDB.PathwayRelationship_SEQ;
