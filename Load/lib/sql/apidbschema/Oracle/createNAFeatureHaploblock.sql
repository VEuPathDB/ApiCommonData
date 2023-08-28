------------------------------------------------------------------------------

CREATE TABLE ApiDB.NAFeatureHaploblock (
 na_feature_HAPBLOCK_ID               NUMBER(10) not null,
 NA_FEATURE_ID                        NUMBER(10) not null,
 HAPLOTYPE_BLOCK_NAME                 VARCHAR2(50) not null,
 LOD_SCORE_MANT                       FLOAT(126),
 LOD_SCORE_EXP                        NUMBER(8),
 EXTERNAL_DATABASE_RELEASE_ID         NUMBER(10),
 MODIFICATION_DATE                    DATE,
 USER_READ                            NUMBER(1),
 USER_WRITE                           NUMBER(1),
 GROUP_READ                           NUMBER(1),
 GROUP_WRITE                          NUMBER(1),
 OTHER_READ                           NUMBER(1),
 OTHER_WRITE                          NUMBER(1),
 ROW_USER_ID                          NUMBER(12),
 ROW_GROUP_ID                         NUMBER(3),
 ROW_PROJECT_ID                       NUMBER(4),
 ROW_ALG_INVOCATION_ID                NUMBER(12),
 FOREIGN KEY (NA_FEATURE_ID) REFERENCES DoTS.NaFeatureImp (NA_FEATURE_ID),
 FOREIGN KEY (EXTERNAL_DATABASE_RELEASE_ID) REFERENCES SRes.ExternalDatabaseRelease (EXTERNAL_DATABASE_RELEASE_ID),
 PRIMARY KEY (na_feature_HAPBLOCK_ID)
 );

GRANT INSERT, SELECT, UPDATE, DELETE ON ApiDB.NAFeatureHaploblock TO gus_w;
GRANT SELECT ON ApiDB.NAFeatureHaploblock TO gus_r;

CREATE INDEX apidb.NaFeatHapBlock_idx
ON ApiDB.NAFeatureHaploblock (NA_FEATURE_ID,HAPLOTYPE_BLOCK_NAME) tablespace indx;

CREATE INDEX apidb.gfls_revfk1_idx
ON ApiDB.NAFeatureHaploblock (EXTERNAL_DATABASE_RELEASE_ID, NA_FEATURE_HAPBLOCK_ID) tablespace indx;

CREATE SEQUENCE apidb.NAFeatureHaploblock_sq;

GRANT SELECT ON apidb.NAFeatureHaploblock_sq TO gus_r;
GRANT SELECT ON apidb.NAFeatureHaploblock_sq TO gus_w;


INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable,
     modification_date, user_read, user_write, group_read, group_write,
     other_read, other_write, row_user_id, row_group_id, row_project_id,
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'NAFeatureHaploblock',
       'Standard', 'NA_FEATURE_HAPBLOCK_ID',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'NAFeatureHaploblock' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);


exit;
