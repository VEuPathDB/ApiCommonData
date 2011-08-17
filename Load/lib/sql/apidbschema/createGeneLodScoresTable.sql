GRANT references ON DoTS.NaFeature TO ApiDB;
GRANT references ON SRes.ExternalDatabaseRelease TO ApiDB;
GRANT references ON DoTS.ChromosomeElementFeature TO ApiDB;
------------------------------------------------------------------------------

CREATE TABLE ApiDB.GeneFeatureLodsScore (
 GENE_HAPBLOCK_SCORE_ID               NUMBER(10) not null,
 NA_FEATURE_ID                        NUMBER(10) not null,
 HAPLOTYPE_BLOCK_NAME                 VARCHAR2(50) not null,
 LOD_SCORE_MANT                       FLOAT(126),
 LOD_SCORE_EXP                        NUMBER(8),
 EXTERNAL_DATABASE_RELEASE_ID         NUMBER(10),
 FOREIGN KEY (NA_FEATURE_ID) REFERENCES DoTS.NaFeature (NA_FEATURE_ID),
 FOREIGN KEY (HAPLOTYPE_BLOCK_NAME) REFERENCES DoTS.ChromosomeElementFeature (NAME),
 FOREIGN KEY (EXTERNAL_DATABASE_RELEASE_ID) REFERENCES SRes.ExternalDatabaseRelease (EXTERNAL_DATABASE_RELEASE_ID),
 PRIMARY KEY (GENE_HAPBLOCK_SCORE_ID)
 );

GRANT INSERT, SELECT, UPDATE, DELETE ON ApiDB.GeneFeatureLodsScore TO gus_w;
GRANT SELECT ON ApiDB.GeneFeatureLodsScore TO gus_r;

CREATE INDEX apidb.lodScore_idx
ON ApiDB.GeneFeatureLodsScore (GENE_HAPBLOCK_SCORE_ID);

CREATE INDEX apidb.geneHapBlock_idx
ON ApiDB.GeneFeatureLodsScore (NA_FEATURE_ID,HAPLOTYPE_BLOCK_NAME);

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable,
     modification_date, user_read, user_write, group_read, group_write,
     other_read, other_write, row_user_id, row_group_id, row_project_id,
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'GeneFeatureLodsScore',
       'Standard', 'GENE_HAPBLOCK_SCORE_ID',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'GeneFeatureLodsScore' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);


exit;
