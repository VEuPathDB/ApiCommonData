CREATE TABLE ApiDB.ChrCopyNumber (
  CHR_COPY_NUMBER_ID            NUMERIC(12)    NOT NULL,
  PROTOCOL_APP_NODE_ID          NUMERIC(10)    NOT NULL,
  NA_SEQUENCE_ID                NUMERIC(12)    NOT NULL,
  CHR_COPY_NUMBER               NUMERIC(10),
  MODIFICATION_DATE             DATE,
  USER_READ                     NUMERIC(1),
  USER_WRITE                    NUMERIC(1),
  GROUP_READ                    NUMERIC(10),
  GROUP_WRITE                   NUMERIC(1),
  OTHER_READ                    NUMERIC(1),
  OTHER_WRITE                   NUMERIC(1),
  ROW_USER_ID                   NUMERIC(12),
  ROW_GROUP_ID                  NUMERIC(4),
  ROW_PROJECT_ID        	    NUMERIC(4),
  ROW_ALG_INVOCATION_ID		    NUMERIC(12),
  PRIMARY KEY (CHR_COPY_NUMBER_ID),
  FOREIGN KEY (PROTOCOL_APP_NODE_ID) REFERENCES Study.ProtocolAppNode (PROTOCOL_APP_NODE_ID),
  FOREIGN KEY (NA_SEQUENCE_ID) REFERENCES DoTS.NASequenceImp (NA_SEQUENCE_ID)
);

CREATE INDEX ccn_revix1 ON apidb.ChrCopyNumber (na_sequence_id, chr_copy_number_id) TABLESPACE indx;
CREATE INDEX ccn_revix0 ON apidb.ChrCopyNumber (protocol_app_node_id, chr_copy_number_id) TABLESPACE indx;

CREATE TABLE ApiDB.GeneCopyNumber (
  GENE_COPY_NUMBER_ID            NUMERIC(12)  NOT NULL,
  PROTOCOL_APP_NODE_ID           NUMERIC(10)  NOT NULL,
  NA_FEATURE_ID 	             NUMERIC(12)  NOT NULL,
  HAPLOID_NUMBER 		  	     FLOAT8,
  REF_COPY_NUMBER                NUMERIC(10),
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
  PRIMARY KEY (GENE_COPY_NUMBER_ID),
  FOREIGN KEY (PROTOCOL_APP_NODE_ID) REFERENCES Study.ProtocolAppNode (PROTOCOL_APP_NODE_ID),
  FOREIGN KEY (NA_FEATURE_ID) REFERENCES DoTS.NAFeatureImp (NA_FEATURE_ID)
);

CREATE INDEX gcn_revix0 ON apidb.GeneCopyNumber (na_feature_id, gene_copy_number_id) TABLESPACE indx;
CREATE INDEX gcn_revix1 ON apidb.GeneCopyNumber (PROTOCOL_APP_NODE_ID, GENE_COPY_NUMBER_ID) tablespace indx;

CREATE SEQUENCE ApiDB.ChrCopyNumber_SQ;
CREATE SEQUENCE ApiDB.GeneCopyNumber_SQ;

GRANT SELECT ON ApiDB.ChrCopyNumber TO gus_r;
GRANT SELECT ON ApiDB.GeneCopyNumber TO gus_r;

GRANT INSERT, SELECT, UPDATE, DELETE ON ApiDB.ChrCopyNumber TO gus_w;
GRANT INSERT, SELECT, UPDATE, DELETE ON ApiDB.GeneCopyNumber TO gus_w;

GRANT SELECT ON ApiDB.ChrCopyNumber_SQ TO gus_r;
GRANT SELECT ON ApiDB.ChrCopyNumber_SQ TO gus_w;
GRANT SELECT ON ApiDB.GeneCopyNumber_SQ TO gus_r;
GRANT SELECT ON ApiDB.GeneCopyNumber_SQ TO gus_w;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable,
     modification_date, user_read, user_write, group_read, group_write,
     other_read, other_write, row_user_id, row_group_id, row_project_id,
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'ChrCopyNumber',
       'Standard', 'CHR_COPY_NUMBER_ID',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'ChrCopyNumber' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable,
     modification_date, user_read, user_write, group_read, group_write,
     other_read, other_write, row_user_id, row_group_id, row_project_id,
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'GeneCopyNumber',
       'Standard', 'GENE_COPY_NUMBER_ID',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'GeneCopyNumber' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);
