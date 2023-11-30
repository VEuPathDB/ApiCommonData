create table ApiDB.CrisprPhenotype (
 crispr_phenotype_id                       NUMERIC(10) ,
 protocol_app_node_id         NUMERIC(10) NOT NULL,
 na_feature_id               NUMERIC(12) NOT NULL,
 mean_phenotype               float8,
 STANDARD_ERROR               float8,
 gene_fdr                     float8,
 sg_fdr                       float8,
 rank                         NUMERIC(8),
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
 FOREIGN KEY (na_feature_id) REFERENCES Dots.NAFeatureImp,
 FOREIGN KEY (protocol_app_node_id) REFERENCES Study.ProtocolAppNode,
 PRIMARY KEY (crispr_phenotype_id)
);

CREATE INDEX crsprp_revix0 ON apidb.CrisprPhenotype (na_feature_id, crispr_phenotype_id) TABLESPACE indx;
CREATE INDEX crsprp_revix1 ON apidb.CrisprPhenotype (protocol_app_node_id, crispr_phenotype_id) TABLESPACE indx;

CREATE SEQUENCE apidb.CrisprPhenotype_sq;

GRANT insert, select, update, delete ON apidb.CrisprPhenotype TO gus_w;
GRANT select ON apidb.CrisprPhenotype TO gus_r;
GRANT select ON apidb.CrisprPhenotype_sq TO gus_w;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'CrisprPhenotype',
       'Standard', 'crispr_phenotype_id',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'crisprphenotype' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);
