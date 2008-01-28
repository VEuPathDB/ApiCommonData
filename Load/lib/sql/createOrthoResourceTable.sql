CREATE TABLE ApiDB.OrthomclResource (
 orthomcl_resource_id          NUMBER(10) NOT NULL,
 orthomcl_taxon_id             NUMBER(10) NOT NULL,
 resource_name                 VARCHAR(50) NOT NULL,
 resource_url                  VARCHAR(255) NOT NULL,
 resource_version              VARCHAR(50),
 strain                        VARCHAR(50),
 description                   VARCHAR(255),
 modification_date             DATE NOT NULL,
 user_read                     NUMBER(1) NOT NULL,
 user_write                    NUMBER(1) NOT NULL,
 group_read                    NUMBER(1) NOT NULL,
 group_write                   NUMBER(1) NOT NULL,
 other_read                    NUMBER(1) NOT NULL,
 other_write                   NUMBER(1) NOT NULL,
 row_user_id                   NUMBER(12) NOT NULL,
 row_group_id                  NUMBER(3) NOT NULL,
 row_project_id                NUMBER(4) NOT NULL,
 row_alg_invocation_id         NUMBER(12) NOT NULL,
 FOREIGN KEY (orthomcl_taxon_id) REFERENCES ApiDB.OrthomclTaxon (orthomcl_taxon_id),
 PRIMARY KEY (orthomcl_resource_id)
);

GRANT insert, select, update, delete ON ApiDB.OrthomclResource TO gus_w;
GRANT select ON ApiDB.OrthomclResource TO gus_r;

CREATE SEQUENCE ApiDB.OrthomclResource_sq;

GRANT SELECT ON ApiDB.OrthomclResource_sq TO gus_r;
GRANT SELECT ON ApiDB.OrthomclResource_sq TO gus_w;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable,
     modification_date, user_read, user_write, group_read, group_write,
     other_read, other_write, row_user_id, row_group_id, row_project_id,
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'OrthomclResource',
       'Standard', 'orthomcl_resource_id',
       d.database_id, 0, 0, '', '', 1, sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'OrthomclResource' NOT IN (SELECT name FROM core.TableInfo
                                 WHERE database_id = d.database_id);
