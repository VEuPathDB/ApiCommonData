CREATE TABLE apidb.Metadatatype (
METADATA_TYPE_ID             NOT NULL NUMBER(12),    
ONTOLOGY_TERM_ID             NOT NULL NUMBER(12),   
NAME                                  VARCHAR2(255), 
DISPLAY_DESCRIPTION                   VARCHAR2(4000),
ORDER_NUM                             VARCHAR2(20),
EXTERNAL_DATABASE_RELEASE_ID          NUMBER(12),    
VARIABLE_TYPE                         VARCHAR2(20),  
UNITS                                 VARCHAR2(50),
MODIFICATION_DATE            NOT NULL DATE,          
USER_READ                    NOT NULL NUMBER(1),     
USER_WRITE                   NOT NULL NUMBER(1),     
GROUP_READ                   NOT NULL NUMBER(1),     
GROUP_WRITE                  NOT NULL NUMBER(1),     
OTHER_READ                   NOT NULL NUMBER(1),     
OTHER_WRITE                  NOT NULL NUMBER(1),     
ROW_USER_ID                  NOT NULL NUMBER(12),    
ROW_GROUP_ID                 NOT NULL NUMBER(3),     
ROW_PROJECT_ID               NOT NULL NUMBER(4),     
ROW_ALG_INVOCATION_ID        NOT NULL NUMBER(12)
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
