CREATE TABLE ApiDB.GeneCNV (
  GENE_CNV_ID                   NUMERIC(12)    NOT NULL,
  ENTITY_ID                     NUMERIC(12)    NOT NULL,
  NA_SEQUENCE_ID                NUMERIC(12)    NOT NULL,
  CHR_COPY_NUMBER               NUMERIC(10),
  MODIFICATION_DATE             TIMESTAMP,
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
  PRIMARY KEY (GENE_CNV_ID),
  FOREIGN KEY (ENTITY_ID) REFERENCES Eda.Entityattributes (ENTITY_ATTRIBUTES_ID),
  FOREIGN KEY (NA_SEQUENCE_ID) REFERENCES DoTS.NASequenceImp (NA_SEQUENCE_ID)
);

CREATE INDEX gcnv_revix1 ON apidb.GeneCNV (na_sequence_id, gene_cnv_id) TABLESPACE indx;
CREATE INDEX gcnv_revix0 ON apidb.GeneCNV (entity_id, gene_cnv_id) TABLESPACE indx;

CREATE TABLE ApiDB.Ploidy (
  PLOIDY_ID                      NUMERIC(12)  NOT NULL,
  ENTITY_ID                      NUMERIC(12)  NOT NULL,
  NA_FEATURE_ID 	         NUMERIC(12)  NOT NULL,
  HAPLOID_NUMBER 		 FLOAT8,
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
  PRIMARY KEY (PLOIDY_ID),
  FOREIGN KEY (ENTITY_ID) REFERENCES Eda.Entityattributes (ENTITY_ATTRIBUTES_ID),
  FOREIGN KEY (NA_FEATURE_ID) REFERENCES DoTS.NAFeatureImp (NA_FEATURE_ID)
);

CREATE INDEX pldy_revix0 ON apidb.Ploidy (na_feature_id, ploidy_id) TABLESPACE indx;
CREATE INDEX pldy_revix1 ON apidb.Ploidy (ENTITY_ID, PLOIDY_ID) tablespace indx;

CREATE SEQUENCE ApiDB.GeneCNV_SQ;
CREATE SEQUENCE ApiDB.Ploidy_SQ;

GRANT SELECT ON ApiDB.GeneCNV TO gus_r;
GRANT SELECT ON ApiDB.Ploidy TO gus_r;

GRANT INSERT, SELECT, UPDATE, DELETE ON ApiDB.GeneCNV TO gus_w;
GRANT INSERT, SELECT, UPDATE, DELETE ON ApiDB.Ploidy TO gus_w;

GRANT SELECT ON ApiDB.GeneCNV_SQ TO gus_r;
GRANT SELECT ON ApiDB.GeneCNV_SQ TO gus_w;
GRANT SELECT ON ApiDB.Ploidy_SQ TO gus_r;
GRANT SELECT ON ApiDB.Ploidy_SQ TO gus_w;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable,
     modification_date, user_read, user_write, group_read, group_write,
     other_read, other_write, row_user_id, row_group_id, row_project_id,
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'GeneCNV',
       'Standard', 'GENE_CNV_ID',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'GeneCNV' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable,
     modification_date, user_read, user_write, group_read, group_write,
     other_read, other_write, row_user_id, row_group_id, row_project_id,
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'Ploidy',
       'Standard', 'PLOIDY_ID',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'Ploidy' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);
