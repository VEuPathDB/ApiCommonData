DROP VIEW dots.IsolateSource;

CREATE VIEW dots.IsolateSource as 
SELECT 
 NA_FEATURE_ID,
 NA_SEQUENCE_ID,
 SUBCLASS_VIEW,
 NAME,
 SEQUENCE_ONTOLOGY_ID,
 PARENT_ID,
 EXTERNAL_DATABASE_RELEASE_ID,
 SOURCE_ID,
 PREDICTION_ALGORITHM_ID,
 IS_PREDICTED,
 REVIEW_STATUS_ID,
 STRING1 AS CELL_LINE,
 STRING2 AS CELL_TYPE,
 STRING3 AS CHROMOPLAST,
 STRING4 AS CHROMOSOME,
 STRING5 AS CLONE,
 STRING6 AS CLONE_LIB,
 STRING7 AS COUNTRY,
 STRING8 AS ISOLATION_SOURCE,
 STRING9 AS NOTE,
 STRING10 AS PCR_PRIMERS,
 STRING11 AS ALLELE,
 STRING12 AS COLLECTION_DATE,
 STRING13 AS COLLECTED_BY,
 STRING14 AS ISOLATE,
 STRING15 AS DEV_STAGE,
 STRING16 AS LAB_HOST,
 STRING18 AS ORGANELLE,
 STRING19 AS POP_VARIANT,
 STRING20 AS TISSUE_TYPE,
 STRING25 AS HAPLOTYPE,
 STRING26 AS SPECIFIC_HOST,
 STRING27 AS STRAIN,
 STRING28 AS SUB_CLONE,
 STRING29 AS SUB_SPECIES,
 STRING30 AS SUB_STRAIN,
 STRING31 AS SEROTYPE,
 STRING34 AS VIRION,
 STRING35 AS ENVIRONMENTAL_SAMPLE,
 STRING36 AS MOL_TYPE,
 STRING38 AS ORGANISM,
 NUMBER1 AS IS_REFERENCE,
 MODIFICATION_DATE,
 USER_READ,
 USER_WRITE,
 GROUP_READ,
 GROUP_WRITE,
 OTHER_READ,
 OTHER_WRITE,
 ROW_USER_ID,
 ROW_GROUP_ID,
 ROW_PROJECT_ID,
 ROW_ALG_INVOCATION_ID
FROM DoTS.NAFeatureImp  
WHERE subclass_view='IsolateSource' 
;

GRANT INSERT, SELECT, UPDATE, DELETE ON dots.IsolateSource TO gus_w;
GRANT SELECT ON dots.IsolateSource TO gus_r;

------------------------------------------------------------------------------

DELETE core.TableInfo where name='IsolateSource';

Commit;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'IsolateSource',
       'Standard', 'NA_Feature_ID',
       d.database_id, 1, 1, v.table_id, s.table_id, 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'dots') d,
     (SELECT table_id FROM core.TableInfo WHERE lower(name) = 'nafeatureimp') v,
     (SELECT table_id FROM core.TableInfo WHERE lower(name) = 'nafeature') s
WHERE 'IsolateSource' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);

------------------------------------------------------------------------------
DROP VIEW dotsVer.IsolateSourceVer;

CREATE VIEW dotsVer.IsolateSourceVer as 
SELECT 
 NA_FEATURE_ID,
 NA_SEQUENCE_ID,
 SUBCLASS_VIEW,
 NAME,
 SEQUENCE_ONTOLOGY_ID,
 PARENT_ID,
 EXTERNAL_DATABASE_RELEASE_ID,
 SOURCE_ID,
 PREDICTION_ALGORITHM_ID,
 IS_PREDICTED,
 REVIEW_STATUS_ID,
 STRING1 AS CELL_LINE,
 STRING2 AS CELL_TYPE,
 STRING3 AS CHROMOPLAST,
 STRING4 AS CHROMOSOME,
 STRING5 AS CLONE,
 STRING6 AS CLONE_LIB,
 STRING7 AS COUNTRY,
 STRING8 AS ISOLATION_SOURCE,
 STRING9 AS NOTE,
 STRING10 AS PCR_PRIMERS,
 STRING11 AS ALLELE,
 STRING12 AS COLLECTION_DATE,
 STRING13 AS COLLECTED_BY,
 STRING14 AS ISOLATE,
 STRING15 AS DEV_STAGE,
 STRING16 AS LAB_HOST,
 STRING18 AS ORGANELLE,
 STRING19 AS POP_VARIANT,
 STRING20 AS TISSUE_TYPE,
 STRING25 AS HAPLOTYPE,
 STRING26 AS SPECIFIC_HOST,
 STRING27 AS STRAIN,
 STRING28 AS SUB_CLONE,
 STRING29 AS SUB_SPECIES,
 STRING30 AS SUB_STRAIN,
 STRING31 AS SEROTYPE,
 STRING34 AS VIRION,
 STRING35 AS ENVIRONMENTAL_SAMPLE,
 STRING36 AS MOL_TYPE,
 STRING38 AS ORGANISM,
 NUMBER1 AS IS_REFERENCE,
 MODIFICATION_DATE,
 USER_READ,
 USER_WRITE,
 GROUP_READ,
 GROUP_WRITE,
 OTHER_READ,
 OTHER_WRITE,
 ROW_USER_ID,
 ROW_GROUP_ID,
 ROW_PROJECT_ID,
 ROW_ALG_INVOCATION_ID, VERSION_ALG_INVOCATION_ID, VERSION_DATE, VERSION_TRANSACTION_ID 
FROM dotsVer.NaFeatureImpVer
WHERE subclass_view='IsolateSource' 
;

GRANT INSERT, SELECT, UPDATE, DELETE ON dotsVer.IsolateSourceVer TO gus_w;
GRANT SELECT ON dotsVer.IsolateSourceVer TO gus_r;

------------------------------------------------------------------------------

DELETE core.TableInfo where name='IsolateSourceVer';

Commit;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'IsolateSourceVer',
       'Version', 'NA_Feature_ID',
       d.database_id, 1, 1, v.table_id, s.table_id, 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'dotsver') d,
     (SELECT table_id FROM core.TableInfo WHERE lower(name) = 'nafeatureimpver') v,
     (SELECT table_id FROM core.TableInfo WHERE lower(name) = 'nafeaturever') s
WHERE 'IsolateSourceVer' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);

------------------------------------------------------------------------------
exit;
