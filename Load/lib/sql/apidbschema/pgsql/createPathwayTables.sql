CREATE TABLE ApiDB.PathwayReaction (
  PATHWAY_REACTION_ID           NUMERIC(12)    NOT NULL,
  SOURCE_ID                     VARCHAR(100)   NOT NULL,
  DESCRIPTION                   VARCHAR(255),
  EQUATION                    	VARCHAR(255),  
  MODIFICATION_DATE             DATE,
  USER_READ                     NUMERIC(1),
  USER_WRITE                    NUMERIC(1),
  GROUP_READ                    NUMERIC(10),
  GROUP_WRITE                   NUMERIC(1),
  OTHER_READ                    NUMERIC(1),
  OTHER_WRITE                   NUMERIC(1),
  ROW_USER_ID                   NUMERIC(12),
  ROW_GROUP_ID                  NUMERIC(4),
  ROW_PROJECT_ID        	NUMERIC(4),
  ROW_ALG_INVOCATION_ID		NUMERIC(12),
  PRIMARY KEY (PATHWAY_REACTION_ID)
);


CREATE TABLE ApiDB.PathwayReactionRel (
  PATHWAY_REACTION_REL_ID       NUMERIC(12)  NOT NULL,
  PATHWAY_REACTION_ID               	 NUMERIC(10)  NOT NULL,
  PATHWAY_RELATIONSHIP_ID 	 NUMERIC(12)  NOT NULL,
  PATHWAY_ID 		  	 NUMERIC(12),
  MODIFICATION_DATE              DATE,
  USER_READ                      NUMERIC(1),
  USER_WRITE                     NUMERIC(1),
  GROUP_READ                     NUMERIC(1),
  GROUP_WRITE                    NUMERIC(1),
  OTHER_READ                     NUMERIC(1),
  OTHER_WRITE                    NUMERIC(1),
  ROW_USER_ID                    NUMERIC(12),
  ROW_GROUP_ID                   NUMERIC(3),
  ROW_PROJECT_ID                 NUMERIC(4),
  ROW_ALG_INVOCATION_ID          NUMERIC(12),
  PRIMARY KEY (PATHWAY_REACTION_REL_ID),
  FOREIGN KEY (PATHWAY_REACTION_ID) REFERENCES ApiDB.PathwayReaction (PATHWAY_REACTION_ID),
  FOREIGN KEY (PATHWAY_ID) REFERENCES SRes.Pathway (PATHWAY_ID),
  FOREIGN KEY (PATHWAY_RELATIONSHIP_ID) REFERENCES SRes.PathwayRelationship (PATHWAY_RELATIONSHIP_ID)
);

CREATE INDEX prr_revix0 ON apidb.PathwayReactionRel (pathway_id, pathway_reaction_rel_id) TABLESPACE indx;
CREATE INDEX prr_revix1 ON apidb.PathwayReactionRel (pathway_reaction_id, pathway_reaction_rel_id) TABLESPACE indx;
CREATE INDEX prr_revix2 ON apidb.PathwayReactionRel (pathway_relationship_id, pathway_reaction_rel_id) TABLESPACE indx;

CREATE TABLE ApiDB.PathwayReactionXRef (
  PATHWAY_REACTION_XREF_ID   		 NUMERIC(12)  NOT NULL,
  PATHWAY_REACTION_ID               	 NUMERIC(10)  NOT NULL,
  ASSOCIATED_REACTION_ID 	 NUMERIC(10)  NOT NULL,
  EXTERNAL_DATABASE_RELEASE_ID   NUMERIC(10)  NOT NULL,
  MODIFICATION_DATE       	 DATE,
  USER_READ               	 NUMERIC(1),
  USER_WRITE              	 NUMERIC(1),
  GROUP_READ              	 NUMERIC(1),
  GROUP_WRITE             	 NUMERIC(1),
  OTHER_READ              	 NUMERIC(1),
  OTHER_WRITE             	 NUMERIC(1),
  ROW_USER_ID            	 NUMERIC(12),
  ROW_GROUP_ID            	 NUMERIC(4),
  ROW_PROJECT_ID          	 NUMERIC(4),
  ROW_ALG_INVOCATION_ID   	 NUMERIC(12),
  PRIMARY KEY (PATHWAY_REACTION_XREF_ID),
  FOREIGN KEY (PATHWAY_REACTION_ID) REFERENCES ApiDB.PathwayReaction (PATHWAY_REACTION_ID),
  FOREIGN KEY (ASSOCIATED_REACTION_ID) REFERENCES ApiDB.PathwayReaction (PATHWAY_REACTION_ID),
  FOREIGN KEY (EXTERNAL_DATABASE_RELEASE_ID) REFERENCES sres.ExternalDatabaseRelease (EXTERNAL_DATABASE_RELEASE_ID)
);

CREATE INDEX prxr_revix0 ON apidb.PathwayReactionXRef (associated_reaction_id, pathway_reaction_xref_id) TABLESPACE indx;
CREATE INDEX prxr_revix1 ON apidb.PathwayReactionXRef (pathway_reaction_id, pathway_reaction_xref_id) TABLESPACE indx;
CREATE INDEX PATHWAYREACTIONXREF_revix1 on APIDB.PATHWAYREACTIONXREF (EXTERNAL_DATABASE_RELEASE_ID, PATHWAY_REACTION_XREF_ID) TABLESPACE indx;

CREATE SEQUENCE ApiDB.PathwayReaction_SQ;
CREATE SEQUENCE ApiDB.PathwayReactionRel_SQ;
CREATE SEQUENCE ApiDB.PathwayReactionXRef_SQ;


GRANT SELECT ON ApiDB.PathwayReaction TO gus_r;
GRANT SELECT ON ApiDB.PathwayReactionRel TO gus_r;
GRANT SELECT ON ApiDB.PathwayReactionXRef TO gus_r;


GRANT INSERT, SELECT, UPDATE, DELETE ON ApiDB.PathwayReaction TO gus_w;
GRANT INSERT, SELECT, UPDATE, DELETE ON ApiDB.PathwayReactionRel TO gus_w;
GRANT INSERT, SELECT, UPDATE, DELETE ON ApiDB.PathwayReactionXRef TO gus_w;

GRANT SELECT ON ApiDB.PathwayReaction_SQ TO gus_r;
GRANT SELECT ON ApiDB.PathwayReaction_SQ tO gus_w;
GRANT SELECT ON ApiDB.PathwayReactionRel_SQ TO gus_r;
GRANT SELECT ON ApiDB.PathwayReactionRel_SQ TO gus_w;
GRANT SELECT ON ApiDB.PathwayReactionXRef_SQ TO gus_r;
GRANT SELECT ON ApiDB.PathwayReactionXRef_SQ TO gus_w;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable,
     modification_date, user_read, user_write, group_read, group_write,
     other_read, other_write, row_user_id, row_group_id, row_project_id,
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'PathwayReaction',
       'Standard', 'PATHWAY_REACTION_ID',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'PathwayReaction' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable,
     modification_date, user_read, user_write, group_read, group_write,
     other_read, other_write, row_user_id, row_group_id, row_project_id,
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'PathwayReactionRel',
       'Standard', 'PATHWAY_REACTION_REL_ID',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'PathwayReactionRel' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable,
     modification_date, user_read, user_write, group_read, group_write,
     other_read, other_write, row_user_id, row_group_id, row_project_id,
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'PathwayReactionXRef',
       'Standard', 'PATHWAY_REACTION_XREF_ID',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'PathwayReactionXRef' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);

