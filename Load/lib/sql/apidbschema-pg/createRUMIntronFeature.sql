
CREATE TABLE apidb.RUMIntronFeature (
 RUM_intron_feature_id       NUMERIC(10),
 external_database_release_id NUMERIC(10) NOT NULL,
 sample_name                  character varying(100) NOT NULL,
 na_sequence_id               NUMERIC(10) NOT NULL,
 mapping_start                     NUMERIC(10) NOT NULL,
 mapping_end                     NUMERIC(10) NOT NULL,
 score                    NUMERIC(10),
 known_intron                    NUMERIC(10),
 standard_splice_signal                    NUMERIC(10),
 signal_not_canonical                    NUMERIC(10),
 ambiguous                    NUMERIC(10),
 long_overlap_unique_reads                    NUMERIC(10),
 short_overlap_unique_reads                    NUMERIC(10),
 long_overlap_nu_reads                    NUMERIC(10),
 short_overlap_nu_reads                    NUMERIC(10),
 MODIFICATION_DATE            TIMESTAMP,
 USER_READ                    NUMERIC(1),
 USER_WRITE                   NUMERIC(1),
 GROUP_READ                   NUMERIC(1),
 GROUP_WRITE                  NUMERIC(1),
 OTHER_READ                   NUMERIC(1),
 OTHER_WRITE                  NUMERIC(1),
 ROW_USER_ID                  NUMERIC(12),
 ROW_GROUP_ID                 NUMERIC(3),
 ROW_PROJECT_ID               NUMERIC(4),
 ROW_ALG_INVOCATION_ID        NUMERIC(12),
 FOREIGN KEY (external_database_release_id) REFERENCES SRes.ExternalDatabaseRelease,
 PRIMARY KEY (RUM_intron_feature_id)
);

CREATE SEQUENCE apidb.RUMIntronFeature_sq;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT nextval('core.tableinfo_sq'), 'RUMIntronFeature',
       'Standard', 'RUM_intron_feature_id',
       (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb'), 0, 0, NULL, NULL, 
       1,current_timestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo), 0
WHERE lower('RUMIntronFeature') NOT IN (SELECT lower(name) FROM core.TableInfo
        WHERE database_id = (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb'));


