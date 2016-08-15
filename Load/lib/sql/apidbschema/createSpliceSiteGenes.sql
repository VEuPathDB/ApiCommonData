/* table for SpliceSite sites */
CREATE TABLE apidb.SpliceSiteGenes (
  splice_site_gene_id       NUMBER(10) not  null,
  splice_site_feature_id        NUMBER(10) not null,
   protocol_app_node_id         NUMBER(10) NOT NULL,
  source_id                     VARCHAR2(50),
  is_dominant                   NUMBER(1), 
  percent_fraction              NUMBER(3), 
  first_atg_location            NUMBER(10),
  dist_to_first_atg             NUMBER(10),
  MODIFICATION_DATE            DATE,
  USER_READ                    NUMBER(1),
  USER_WRITE                   NUMBER(1),
  GROUP_READ                   NUMBER(1),
  GROUP_WRITE                  NUMBER(1),
  OTHER_READ                   NUMBER(1),
  OTHER_WRITE                  NUMBER(1),
  ROW_USER_ID                  NUMBER(12),
  ROW_GROUP_ID                 NUMBER(3),
  ROW_PROJECT_ID               NUMBER(4),
  ROW_ALG_INVOCATION_ID        NUMBER(12),
   FOREIGN KEY (protocol_app_node_id) REFERENCES Study.ProtocolAppNode,
  FOREIGN KEY (splice_site_feature_id) REFERENCES apidb.SpliceSiteFeature,
  PRIMARY KEY (splice_site_gene_id)
);

CREATE SEQUENCE apidb.SpliceSiteGenes_sq;
GRANT select ON apidb.SpliceSiteGenes_sq TO gus_w;

grant select on Apidb.SpliceSiteGenes to gus_r;
grant insert, select, update, delete on Apidb.SpliceSiteGenes to gus_w;


create index apidb.splicesitegenes_data_idx
ON Apidb.SpliceSiteGenes (splice_site_feature_id, protocol_app_node_id, source_id)
tablespace indx;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'SpliceSiteGenes',
       'Standard', 'splice_site_gene_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'SpliceSiteGenes' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);

exit;
