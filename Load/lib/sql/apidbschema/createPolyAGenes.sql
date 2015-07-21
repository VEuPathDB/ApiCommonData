/* table for PolyA sites */

CREATE TABLE apidb.PolyAGenes (
  poly_a_gene_id       NUMBER(10) not  null,
  splice_site_feature_id        NUMBER(10) not null,
  location                      NUMBER(10) not null,
  strand                        CHAR(1), 
  source_id                     VARCHAR2(50),
  dist_to_cds                   NUMBER(10) not null,
  within_cds                    NUMBER(1),
  sample_name                   VARCHAR2(100),
  count                         NUMBER(10),
  count_per_million             FLOAT(126), 
  avg_mismatches                FLOAT(126), 
  is_unique                     NUMBER(1),
  type                          VARCHAR2(50),
  na_sequence_id                NUMBER(10),
  external_database_release_id  NUMBER(10),
  is_dominant                   NUMBER(1), 
  percent_fraction              NUMBER(3), 
  diff_to_next                  NUMBER(3),
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
  FOREIGN KEY (splice_site_feature_id) REFERENCES apidb.SpliceSiteFeature,
  PRIMARY KEY (poly_a_gene_id)	
);

grant select on Apidb.PolyAGenes to gus_r;
grant insert, select, update, delete on Apidb.PolyAGenes to gus_w;

CREATE SEQUENCE apidb.PolyAGenes_sq;

create index apidb.polyagenes_loc_idx
ON Apidb.PolyAGenes (source_id, na_sequence_id, location, type)
tablespace indx;

create index apidb.polyagenes_data_idx
ON Apidb.PolyAGenes (splice_site_feature_id, count_per_million, sample_name, source_id)
tablespace indx;

create index apidb.polyagenes_revfk_idx
ON Apidb.PolyAGenes (splice_site_feature_id, poly_a_gene_id)
tablespace indx;


INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'PolyAGenes',
       'Standard', 'poly_a_gene_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'PolyAGenes' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);

quit;
