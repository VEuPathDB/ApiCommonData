DROP VIEW dots.IsolateFeature;

CREATE VIEW dots.IsolateFeature as 
SELECT NA_Feature_ID, 
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
 STRING1 AS GENE_TYPE, 
 NUMBER1 AS CONFIRMED_BY_SIMILARITY, 
 NUMBER2 AS PREDICTION_NUMBER, 
 NUMBER3 AS NUMBER_OF_EXONS, 
 NUMBER4 AS HAS_INITIAL_EXON, 
 NUMBER5 AS HAS_FINAL_EXON, 
 FLOAT1 AS SCORE, 
 FLOAT2 AS SECONDARY_SCORE, 
 NUMBER6 AS IS_PSEUDO, 
 NUMBER7 AS IS_PARTIAL, 
 STRING2 AS ALLELE, 
 STRING3 AS CITATION, 
 STRING4 AS EVIDENCE, 
 STRING5 AS FUNCTION, 
 STRING6 AS GENE, 
 STRING7 AS LABEL, 
 STRING8 AS MAP, 
 STRING9 AS PHENOTYPE, 
 STRING10 AS PRODUCT, 
 STRING11 AS STANDARD_NAME, 
 STRING12 AS USEDIN, 
 STRING15 AS PRODUCT_ALIAS,
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
WHERE subclass_view='IsolateFeature';

GRANT INSERT, SELECT, UPDATE, DELETE ON dots.IsolateFeature TO gus_w;
GRANT SELECT ON dots.IsolateFeature TO gus_r;

------------------------------------------------------------------------------

DELETE core.TableInfo where name='IsolateFeature';

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'IsolateFeature',
       'Standard', 'NA_Feature_ID',
       d.database_id, 1, 1, v.table_id, s.table_id, 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'dots') d,
     (SELECT table_id FROM core.TableInfo WHERE lower(name) = 'nafeatureimp') v,
     (SELECT table_id FROM core.TableInfo WHERE lower(name) = 'nafeature') s
WHERE 'IsolateFeature' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);

------------------------------------------------------------------------------
exit;
