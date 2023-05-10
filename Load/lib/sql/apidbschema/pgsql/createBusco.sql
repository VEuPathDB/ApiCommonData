CREATE TABLE ApiDB.Busco (
  busco_id        NUMERIC(10) NOT NULL,
  organism_id     NUMERIC(12) NOT NULL,
  sequence_type   VARCHAR(10) NOT NULL,
  C_score               NUMERIC(12),
  S_score               NUMERIC(12),
  D_score               NUMERIC(12),
  F_score               NUMERIC(12),
  M_score               NUMERIC(12),
  external_database_release_id NUMERIC(10) NOT NULL,
  MODIFICATION_DATE     DATE,
  USER_READ             NUMERIC(1),
  USER_WRITE            NUMERIC(1),
  GROUP_READ            NUMERIC(1),
  GROUP_WRITE           NUMERIC(1),
  OTHER_READ            NUMERIC(1),
  OTHER_WRITE           NUMERIC(1),
  ROW_USER_ID           NUMERIC(12),
  ROW_GROUP_ID          NUMERIC(3),
  ROW_PROJECT_ID        NUMERIC(4),
  ROW_ALG_INVOCATION_ID NUMERIC(12),
  FOREIGN KEY (organism_id) REFERENCES apidb.organism (organism_id),
  FOREIGN KEY (EXTERNAL_DATABASE_RELEASE_ID) REFERENCES sres.ExternalDatabaseRelease (EXTERNAL_DATABASE_RELEASE_ID),
  PRIMARY KEY (busco_id)
);

CREATE SEQUENCE ApiDB.Busco_sq;

GRANT insert, select, update, delete ON ApiDB.Busco TO gus_w;
GRANT select ON ApiDB.Busco TO gus_r;
GRANT select ON ApiDB.Busco_sq TO gus_w;

INSERT INTO core.TableInfo
  (table_id, name, table_type, primary_key_column, database_id,
    is_versioned, is_view, view_on_table_id, superclass_table_id, is_updatable,
    modification_date, user_read, user_write, group_read, group_write,
    other_read, other_write, row_user_id, row_group_id, row_project_id,
    row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'Busco', 'Standard', 'busco_id',
  d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1, p.project_id, 0
FROM
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'Busco' NOT IN (SELECT name FROM core.TableInfo
                      WHERE database_id = d.database_id)
;
