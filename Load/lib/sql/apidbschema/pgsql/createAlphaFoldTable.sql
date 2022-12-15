CREATE TABLE ApiDB.AlphaFold (
  ALPHAFOLD_ID                  NUMERIC(12)  NOT NULL,
  UNIPROT_ID                    VARCHAR(15)  NOT NULL,
  FIRST_RESIDUE_INDEX           NUMERIC(10),
  LAST_RESIDUE_INDEX            NUMERIC(10),
  SOURCE_ID                     VARCHAR(20)  NOT NULL,
  ALPHAFOLD_VERSION             NUMERIC(5)   NOT NULL,
  EXTERNAL_DATABASE_RELEASE_ID  NUMERIC(10)  NOT NULL,
  MODIFICATION_DATE             TIMESTAMP,
  USER_READ                     NUMERIC(1),
  USER_WRITE                    NUMERIC(1),
  GROUP_READ                    NUMERIC(10),
  GROUP_WRITE                   NUMERIC(1),
  OTHER_READ                    NUMERIC(1),
  OTHER_WRITE                   NUMERIC(1),
  ROW_USER_ID                   NUMERIC(12),
  ROW_GROUP_ID                  NUMERIC(4),
  ROW_PROJECT_ID                NUMERIC(4),
  ROW_ALG_INVOCATION_ID         NUMERIC(12),
  PRIMARY KEY (ALPHAFOLD_ID),
  FOREIGN KEY (EXTERNAL_DATABASE_RELEASE_ID) REFERENCES sres.ExternalDatabaseRelease (EXTERNAL_DATABASE_RELEASE_ID)
);

CREATE INDEX af_ix0 on ApiDB.AlphaFold(uniprot_id, alphafold_id) TABLESPACE indx;

CREATE SEQUENCE ApiDB.ALPHAFOLD_SQ;

GRANT SELECT ON ApiDB.AlphaFold TO gus_r;

GRANT INSERT, SELECT, UPDATE, DELETE ON ApiDB.AlphaFold TO gus_w;

GRANT SELECT ON ApiDB.AlphaFold_SQ TO gus_r;
GRANT SELECT ON ApiDB.AlphaFold_SQ TO gus_w;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable,
     modification_date, user_read, user_write, group_read, group_write,
     other_read, other_write, row_user_id, row_group_id, row_project_id,
     row_alg_invocation_id)
SELECT nextval('core.tableinfo_sq'), 'AlphaFold',
       'Standard', 'ALPHAFOLD_ID',
       d.database_id, 0, 0, NULL, NULL, 1,localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'AlphaFold' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);

