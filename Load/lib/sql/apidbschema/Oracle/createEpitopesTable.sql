CREATE TABLE ApiDB.IEDBEpitope (
  iedb_epitope_id		NUMBER(10) NOT NULL,
  iedb_id			NUMBER(10) NOT NULL,
  peptide_sequence	     	varchar(100) NOT NULL,
  peptide_gene_accession     	varchar(100) NOT NULL,
  external_database_release_id	NUMBER(10) NOT NULL,
  MODIFICATION_DATE     	DATE,
  USER_READ             	NUMBER(1),
  USER_WRITE            	NUMBER(1),
  GROUP_READ            	NUMBER(1),
  GROUP_WRITE           	NUMBER(1),
  OTHER_READ            	NUMBER(1),
  OTHER_WRITE           	NUMBER(1),
  ROW_USER_ID           	NUMBER(12),
  ROW_GROUP_ID          	NUMBER(3),
  ROW_PROJECT_ID        	NUMBER(4),
  ROW_ALG_INVOCATION_ID 	NUMBER(12),
  PRIMARY KEY (iedb_epitope_id),
  FOREIGN KEY (external_database_release_id) REFERENCES SRes.ExternalDatabaseRelease (external_database_release_id)
);


CREATE SEQUENCE ApiDB.IEDBEpitope_sq;


GRANT insert, select, update, delete ON ApiDB.IEDBEpitope TO gus_w;
GRANT select ON ApiDB.IEDBEpitope TO gus_r;
GRANT select ON ApiDB.IEDBEpitope TO gus_w;



INSERT INTO core.TableInfo
  (table_id, name, table_type, primary_key_column, database_id,
    is_versioned, is_view, view_on_table_id, superclass_table_id, is_updatable,
    modification_date, user_read, user_write, group_read, group_write,
    other_read, other_write, row_user_id, row_group_id, row_project_id,
    row_alg_invocation_id)
  SELECT core.tableinfo_sq.nextval, 'IEDBEpitope', 'Standard', 'IEDBEpitope_id',
    d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1, p.project_id, 0
  FROM dual,
       (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
       (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
  WHERE 'IEDBEpitope' NOT IN (SELECT name FROM core.TableInfo
  WHERE database_id = d.database_id);


------------------------------------------------------------------------------
CREATE TABLE ApiDB.NAFeatureEpitope (
  na_feature_epitope_id       	NUMBER(10) NOT NULL,
  na_feature_id	       		varchar(100) NOT NULL,
  iedb_id			NUMBER(10) NOT NULL,
  match_type             	varchar(100) NOT NULL,
  blast_hit_indentity  	        NUMBER(10) NOT NULL,
  blast_hit_align_len  	        NUMBER(10) NOT NULL,
  external_database_release_id	NUMBER(10) NOT NULL,
  MODIFICATION_DATE     	DATE,
  USER_READ             	NUMBER(1),
  USER_WRITE            	NUMBER(1),
  GROUP_READ            	NUMBER(1),
  GROUP_WRITE           	NUMBER(1),
  OTHER_READ            	NUMBER(1),
  OTHER_WRITE           	NUMBER(1),
  ROW_USER_ID           	NUMBER(12),
  ROW_GROUP_ID          	NUMBER(3),
  ROW_PROJECT_ID        	NUMBER(4),
  ROW_ALG_INVOCATION_ID 	NUMBER(12),
  PRIMARY KEY (na_feature_epitope_id),
  FOREIGN KEY (external_database_release_id) REFERENCES SRes.ExternalDatabaseRelease (external_database_release_id)
);

-- index na_feature_epitope_id column
--on apidb.NAFeatureEpitope (na_feature_epitope_id) tablespace indx;


CREATE SEQUENCE ApiDB.NAFeatureEpitope_sq;

GRANT insert, select, update, delete ON ApiDB.NAFeatureEpitope TO gus_w;
GRANT select ON ApiDB.NAFeatureEpitope TO gus_r;
GRANT select ON ApiDB.NAFeatureEpitope TO gus_w;

INSERT INTO core.TableInfo
  (table_id, name, table_type, primary_key_column, database_id,
    is_versioned, is_view, view_on_table_id, superclass_table_id, is_updatable,
    modification_date, user_read, user_write, group_read, group_write,
    other_read, other_write, row_user_id, row_group_id, row_project_id,
    row_alg_invocation_id)
  SELECT core.tableinfo_sq.nextval, 'NAFeatureEpitope', 'Standard', 'NAFeatureEpitope_id',
    d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1, p.project_id, 0
  FROM dual,
       (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
       (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
  WHERE 'NAFeatureEpitope' NOT IN (SELECT name FROM core.TableInfo
  WHERE database_id = d.database_id);

------------------------------------------------------------------------------

exit;
