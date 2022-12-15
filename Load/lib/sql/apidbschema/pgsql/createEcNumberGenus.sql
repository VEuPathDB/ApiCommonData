CREATE TABLE ApiDB.EcNumberGenus (
  EC_NUMBER_GENUS_ID	  NUMERIC(12)   NOT NULL,
  EC_NUMBER               VARCHAR(50)  NOT NULL,
  GENUS                   VARCHAR(50)  NOT NULL,
  MODIFICATION_DATE       TIMESTAMP,
  USER_READ               NUMERIC(1),
  USER_WRITE              NUMERIC(1),
  GROUP_READ              NUMERIC(1),
  GROUP_WRITE             NUMERIC(1),
  OTHER_READ              NUMERIC(1),
  OTHER_WRITE             NUMERIC(1),
  ROW_USER_ID             NUMERIC(12),
  ROW_GROUP_ID            NUMERIC(4),
  ROW_PROJECT_ID          NUMERIC(4),
  ROW_ALG_INVOCATION_ID   NUMERIC(12),
  PRIMARY KEY (EC_NUMBER_GENUS_ID)
);


CREATE SEQUENCE ApiDB.EcNumberGenus_SQ;

GRANT SELECT ON ApiDB.EcNumberGenus TO gus_r;
GRANT INSERT, SELECT, UPDATE, DELETE ON ApiDB.EcNumberGenus TO gus_w;
GRANT SELECT ON ApiDB.EcNumberGenus_SQ TO gus_w;


INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable,
     modification_date, user_read, user_write, group_read, group_write,
     other_read, other_write, row_user_id, row_group_id, row_project_id,
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'EcNumberGenus',
       'Standard', 'EC_NUMBER_GENUS_ID',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'EcNumberGenus' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);
