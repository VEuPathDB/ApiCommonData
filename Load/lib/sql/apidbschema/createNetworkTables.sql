create ApiDB.NetworkContext (
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
  PRIMARY KEY (MODEL_CONTEXT_ID)
);


create ApiDB.Network (
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



create ApiDB.NetworkNode (
  NETWORK_NODE_ID                NUMBER(10)  NOT NULL,	
  NODE_TYPE_ID                   NUMBER(10)  NOT NULL,
  TABLE_ID                       NUMBER(5)   NOT NULL,
  ROW_ID                         NUMBER(12)  NOT NULL,
  DISPLAY_LABEL                  VARCHAR(25),
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



create ApiDB.NetworkRelationship (
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


create ApiDB.NetworkRelationshipType(
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


create ApiDB.NetworkRelContext(
  NETWORK_REL_CONTEXT_ID         NUMBER(12)  NOT NULL,
  NETWORK_RELATIONSHIP_ID        NUMBER(12)  NOT NULL,
  NETWORK_RELATIONSHIP_TYPE_ID   NUMBER(11)  NOT NULL,
  NETWORK_CONTEXT_ID             NUMBER(3)   NOT NULL,
  WEIGHT                         FLOAT,
  SOURCE_NODE                    NUMBER(1)
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


create ApiDB.NetworkRelContextLink(
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


CREATE SEQUENCE ApiDB.NetworkContext_sq;
CREATE SEQUENCE ApiDB.Network_sq;
CREATE SEQUENCE ApiDB.NetworkNode_sq;
CREATE SEQUENCE ApiDB.NetworkRelationship_sq;
CREATE SEQUENCE ApiDB.NetworkRelationshipType_sq;
CREATE SEQUENCE ApiDB.NetworkRelContext_sq;
CREATE SEQUENCE ApiDB.NetworkRelContextLink_sq;
