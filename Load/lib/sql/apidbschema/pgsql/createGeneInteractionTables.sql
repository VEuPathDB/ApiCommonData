------------------------------------------------------------------------------

CREATE TABLE apidb.GeneInteraction (
 gene_interaction_id  NUMERIC(10),
 bait_gene_feature_id  NUMERIC(10),
 prey_gene_feature_id  NUMERIC(10),
 bait_start NUMERIC(8),
 bait_end NUMERIC(8),
 prey_start NUMERIC(8),
 prey_end NUMERIC(8),
 times_observed NUMERIC(8),
 number_of_searches NUMERIC(8),
 prey_number_of_baits NUMERIC(8),
 bait_number_of_preys NUMERIC(8),
 MODIFICATION_DATE     TIMESTAMP,
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
 FOREIGN KEY (bait_gene_feature_id) REFERENCES DoTS.NaFeatureImp (na_feature_id),
 FOREIGN KEY (prey_gene_feature_id) REFERENCES DoTS.NaFeatureImp (na_feature_id),
 PRIMARY KEY (gene_interaction_id)
);

CREATE INDEX GeneInteraction_revix1 ON apidb.GeneInteraction (prey_gene_feature_id, gene_interaction_id);
CREATE INDEX GeneInteraction_revix2 ON apidb.GeneInteraction (bait_gene_feature_id, gene_interaction_id);

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
SELECT NEXTVAL('core.tableinfo_sq'), 'GeneInteraction',
       'Standard', 'gene_interaction_id',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'GeneInteraction' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);

------------------------------------------------------------------------------
