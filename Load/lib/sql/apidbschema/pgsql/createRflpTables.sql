CREATE TABLE apidb.RflpGenotype (
 rflp_genotype_id      NUMERIC(10),
 protocol_app_node_id  NUMERIC(10) NOT NULL,
 locus_tag             VARCHAR(20) NOT NULL,
 genotype              VARCHAR(20) NOT NULL,
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
 FOREIGN KEY (protocol_app_node_id) REFERENCES Study.ProtocolAppNode,
 PRIMARY KEY (rflp_genotype_id)
);

CREATE INDEX rflpg_revfk_ix
  ON apidb.RflpGenotype (protocol_app_node_id, locus_tag, genotype, rflp_genotype_id)
tablespace indx;

CREATE SEQUENCE apidb.RflpGenotype_sq;

GRANT insert, select, update, delete ON apidb.RflpGenotype TO gus_w;
GRANT select ON apidb.RflpGenotype TO gus_r;
GRANT select ON apidb.RflpGenotype_sq TO gus_w;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'RflpGenotype',
       'Standard', 'rflp_genotype_id',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'RflpGenotype' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);

------------------------------------------------------------------------------

CREATE TABLE apidb.RflpGenotypeNumber (
 rflp_genotype_id      NUMERIC(10),
 protocol_app_node_id  NUMERIC(10) NOT NULL,
 genotype_number       VARCHAR(20) NOT NULL,
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
 FOREIGN KEY (protocol_app_node_id) REFERENCES Study.ProtocolAppNode,
 PRIMARY KEY (rflp_genotype_id)
);

CREATE INDEX rflpgn_revfk_ix
  ON apidb.RflpGenotypeNumber (protocol_app_node_id, genotype_number, rflp_genotype_id)
tablespace indx;

CREATE SEQUENCE apidb.RflpGenotypeNumber_sq;

GRANT insert, select, update, delete ON apidb.RflpGenotypeNumber TO gus_w;
GRANT select ON apidb.RflpGenotypeNumber TO gus_r;
GRANT select ON apidb.RflpGenotypeNumber_sq TO gus_w;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'RflpGenotypeNumber',
       'Standard', 'rflp_genotype_id',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'RflpGenotypeNumber' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);

------------------------------------------------------------------------------