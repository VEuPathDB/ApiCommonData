
CREATE TABLE apidb.RelatedNaFeature (
 related_na_feature_id  NUMERIC(10),
 na_feature_id  NUMERIC(10) NOT NULL,	
 associated_na_feature_id  NUMERIC(10) NOT NULL,	
 external_database_release_id NUMERIC(10),
 value NUMERIC(10),
 MODIFICATION_DATE     timestamp,
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
 FOREIGN KEY (na_feature_id) REFERENCES DoTS.NaFeatureImp (na_feature_id),
 FOREIGN KEY (associated_na_feature_id) REFERENCES DoTS.NaFeatureImp (na_feature_id),
 FOREIGN KEY (external_database_release_id) REFERENCES SRes.ExternalDatabaseRelease,
 PRIMARY KEY (related_na_feature_id)
);

CREATE INDEX RelatedNaFeature_revix1 ON apidb.RelatedNaFeature (external_database_release_id, related_na_feature_id);
CREATE INDEX RelatedNaFeature_revix2 ON apidb.RelatedNaFeature (associated_na_feature_id, related_na_feature_id);
CREATE INDEX RelatedNaFeature_revix3 ON apidb.RelatedNafeature (na_feature_id, related_na_feature_id);

CREATE SEQUENCE apidb.RelatedNaFeature_sq;


INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT nextval('core.tableinfo_sq'), 'RelatedNaFeature',
       'Standard', 'related_na_feature_id',
       (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb'), 0, 0, NULL, NULL, 
       1,current_timestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo), 0
WHERE lower('RelatedNaFeature') NOT IN (SELECT lower(name) FROM core.TableInfo
        WHERE database_id = (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb'));


------------------------------------------------------------------------------
