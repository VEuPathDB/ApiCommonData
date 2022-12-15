CREATE TABLE apidb.SpliceSiteFeature (
 splice_site_feature_id       NUMERIC(10),
 protocol_app_node_id         NUMERIC(10) NOT NULL,
 na_sequence_id               NUMERIC(10) NOT NULL,
 segment_start                NUMERIC(10) NOT NULL,
 segment_end                  NUMERIC(10) NOT NULL,
 type                         VARCHAR(20) NOT NULL,
 strand                       CHAR(1) NOT NULL,
 count                        NUMERIC(10) NOT NULL,
 is_unique                    NUMERIC(1) NOT NULL,
 avg_mismatches               FLOAT,
 count_per_million            FLOAT,
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
 FOREIGN KEY (protocol_app_node_id) REFERENCES Study.ProtocolAppNode,
 FOREIGN KEY (na_sequence_id) REFERENCES dots.nasequenceimp,
 PRIMARY KEY (splice_site_feature_id)
);

CREATE INDEX ssf_ix0
  ON apidb.SpliceSiteFeature (type, na_sequence_id, is_unique, splice_site_feature_id)
TABLESPACE indx;

CREATE INDEX ssf_revix0
  ON apidb.SpliceSiteFeature (na_sequence_id, splice_site_feature_id)
TABLESPACE indx;

CREATE INDEX ssf_revix1
  ON apidb.SpliceSiteFeature (protocol_app_node_id, splice_site_feature_id)
TABLESPACE indx;

CREATE SEQUENCE apidb.SpliceSiteFeature_sq;

GRANT insert, select, update, delete ON apidb.SpliceSiteFeature TO gus_w;
GRANT select ON apidb.SpliceSiteFeature TO gus_r;
GRANT select ON apidb.SpliceSiteFeature_sq TO gus_w;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'SpliceSiteFeature',
       'Standard', 'splice_site_feature_id',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'SpliceSiteFeature' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);

------------------------------------------------------------------------------