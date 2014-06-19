------------------------------------------------------------------------------

CREATE TABLE apidb.GeneInteraction (
 gene_interaction_id  NUMBER(10),
 bait_gene_feature_id  number(10),	
 prey_gene_feature_id  number(10),	
 bait_start number(8),
 bait_end number(8),
 prey_start number(8),
 prey_end number(8),
 times_observed number(8),
 number_of_searches number(8),
 prey_number_of_baits number(8),
 bait_number_of_preys number(8),
 MODIFICATION_DATE     DATE,
 USER_READ             NUMBER(1),
 USER_WRITE            NUMBER(1),
 GROUP_READ            NUMBER(1),
 GROUP_WRITE           NUMBER(1),
 OTHER_READ            NUMBER(1),
 OTHER_WRITE           NUMBER(1),
 ROW_USER_ID           NUMBER(12),
 ROW_GROUP_ID          NUMBER(3),
 ROW_PROJECT_ID        NUMBER(4),
 ROW_ALG_INVOCATION_ID NUMBER(12),
 FOREIGN KEY (bait_gene_feature_id) REFERENCES DoTS.NaFeatureImp (na_feature_id),
 FOREIGN KEY (prey_gene_feature_id) REFERENCES DoTS.NaFeatureImp (na_feature_id),
 PRIMARY KEY (gene_interaction_id)
);

CREATE INDEX apidb.GeneInteraction_revix1 ON apidb.GeneInteraction (prey_gene_feature_id, gene_interaction_id);
CREATE INDEX apidb.GeneInteraction_revix2 ON apidb.GeneInteraction (bait_gene_feature_id, gene_interaction_id);

CREATE SEQUENCE apidb.GeneInteraction_sq;

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.GeneInteraction TO gus_w;
GRANT SELECT ON apidb.GeneInteraction TO gus_r;
GRANT SELECT ON apidb.GeneInteraction_sq TO gus_w;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'GeneInteraction',
       'Standard', 'gene_interaction_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'GeneInteraction' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);

------------------------------------------------------------------------------
exit;
