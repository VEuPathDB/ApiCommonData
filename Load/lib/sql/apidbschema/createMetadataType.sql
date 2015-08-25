CREATE TABLE apidb.Metadatatype (
METADATA_TYPE_ID             NUMBER(12) NOT NULL,    
ONTOLOGY_TERM_ID             NUMBER(12) NOT NULL,   
NAME                                  VARCHAR2(255), 
DISPLAY_DESCRIPTION                   VARCHAR2(4000),
ORDER_NUM                             VARCHAR2(20),
IS_HIDDEN                             NUMBER(1),
EXTERNAL_DATABASE_RELEASE_ID          NUMBER(12),    
VARIABLE_TYPE                         VARCHAR2(20),  
UNITS                                 VARCHAR2(50),
MODIFICATION_DATE            DATE NOT NULL,          
USER_READ                    NUMBER(1) NOT NULL,     
USER_WRITE                   NUMBER(1) NOT NULL,     
GROUP_READ                   NUMBER(1) NOT NULL,     
GROUP_WRITE                  NUMBER(1) NOT NULL,     
OTHER_READ                   NUMBER(1) NOT NULL,     
OTHER_WRITE                  NUMBER(1) NOT NULL,     
ROW_USER_ID                  NUMBER(12) NOT NULL,    
ROW_GROUP_ID                 NUMBER(3) NOT NULL,     
ROW_PROJECT_ID               NUMBER(4) NOT NULL,     
ROW_ALG_INVOCATION_ID        NUMBER(12) NOT NULL
);

ALTER TABLE apidb.Metadatatype
ADD CONSTRAINT mdt_pk PRIMARY KEY (metadata_type_id);

ALTER TABLE apidb.Metadatatype
ADD CONSTRAINT mss_fk2 FOREIGN KEY (external_database_release_id)
REFERENCES sres.ExternalDatabaseRelease (external_database_release_id);

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.Metadatatype TO gus_w;
GRANT SELECT ON apidb.Metadatatype TO gus_r;

------------------------------------------------------------------------------

CREATE SEQUENCE apidb.Metadatatype_sq;

GRANT SELECT ON apidb.Metadatatype_sq TO gus_r;
GRANT SELECT ON apidb.Metadatatype_sq TO gus_w;

------------------------------------------------------------------------------

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'Metadatatype',
       'Standard', 'ontology_term_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'metadatatype' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);


exit;
