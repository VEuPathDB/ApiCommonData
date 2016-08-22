CREATE TABLE apidb.RflpGenotype (
 rflp_genotype_id      NUMBER(10),
 protocol_app_node_id  NUMBER(10) NOT NULL,
 locus_tag             VARCHAR2(20) NOT NULL,
 genotype              VARCHAR2(20) NOT NULL,
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
 FOREIGN KEY (protocol_app_node_id) REFERENCES Study.ProtocolAppNode,
 PRIMARY KEY (rflp_genotype_id)
);

CREATE INDEX apidb.rflpg_revfk_ix
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
SELECT core.tableinfo_sq.nextval, 'RflpGenotype',
       'Standard', 'rflp_genotype_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'RflpGenotype' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);

------------------------------------------------------------------------------

CREATE TABLE apidb.RflpGenotypeNumber (
 rflp_genotype_id      NUMBER(10),
 protocol_app_node_id  NUMBER(10) NOT NULL,
 genotype_number       VARCHAR2(20) NOT NULL,
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
 FOREIGN KEY (protocol_app_node_id) REFERENCES Study.ProtocolAppNode,
 PRIMARY KEY (rflp_genotype_id)
);

CREATE INDEX apidb.rflpgn_revfk_ix
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
SELECT core.tableinfo_sq.nextval, 'RflpGenotypeNumber',
       'Standard', 'rflp_genotype_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'RflpGenotypeNumber' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);

------------------------------------------------------------------------------

exit;
