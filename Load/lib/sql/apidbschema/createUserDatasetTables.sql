
create table ApiDBUserDataset.InstalledUserDataset(
user_dataset_id not null number(10),
primary key (user_dataset_id)
);

----------------------------------------------------------------------------
create table ApiDBUserDataset.UD_PROTOCOLAPPNODE (
PROTOCOL_APP_NODE_ID         NOT NULL NUMBER(10),     
TYPE_ID                               NUMBER(10),     
NAME                         NOT NULL VARCHAR2(200),  
DESCRIPTION                           VARCHAR2(1000), 
URI                                   VARCHAR2(300),  
USER_DATASET_ID          NUMBER(10),     
SOURCE_ID                             VARCHAR2(100),  
SUBTYPE_ID                            NUMBER(10),     
TAXON_ID                              NUMBER(10),     
NODE_ORDER_NUM                        NUMBER(10),     
ISA_TYPE                              VARCHAR2(50),   
MODIFICATION_DATE            NOT NULL DATE           
USER_READ                    NOT NULL NUMBER(1),      
USER_WRITE                   NOT NULL NUMBER(1),      
GROUP_READ                   NOT NULL NUMBER(1),      
GROUP_WRITE                  NOT NULL NUMBER(1),      
OTHER_READ                   NOT NULL NUMBER(1),      
OTHER_WRITE                  NOT NULL NUMBER(1),      
ROW_USER_ID                  NOT NULL NUMBER(12),     
ROW_GROUP_ID                 NOT NULL NUMBER(4),      
ROW_PROJECT_ID               NOT NULL NUMBER(4),      
ROW_ALG_INVOCATION_ID        NOT NULL NUMBER(12),  
 FOREIGN KEY (user_dataset_id) REFERENCES ApiDBUserDataset.InstalledUserDataset,
 PRIMARY KEY (protocol_app_node_id)
);

CREATE INDEX apiDBUserDataset.UD_PAN_idx1 ON apiDBUserDataset.UD_PROTOCOLAPPNODE (type_id) tablespace indx;
CREATE INDEX apiDBUserDataset.UD_PAN_idx2 ON apiDBUserDataset.UD_PROTOCOLAPPNODE (user_dataset_id) tablespace indx;
CREATE INDEX apiDBUserDataset.UD_PAN_idx3 ON apiDBUserDataset.UD_PROTOCOLAPPNODE (subtype_id) tablespace indx;
CREATE INDEX apiDBUserDataset.UD_PAN_idx4 ON apiDBUserDataset.UD_PROTOCOLAPPNODE (taxon_id, protocol_app_node_id) tablespace indx;

create sequence ApiDBUserDataset.UD_ProtocolAppNode_sq;

GRANT insert, select, update, delete ON ApiDBUserDataset.UD_ProtocolAppNode TO gus_w;
GRANT select ON ApiDBUserDataset.UD_ProtocolAppNode TO gus_r;
GRANT select ON ApiDBUserDataset.UD_ProtocolAppNode_sq TO gus_w;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'UD_ProtocolAppNode',
       'Standard', 'protocol_app_node_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'UD_ProtocolAppNode' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);


-----------------------------------------------------------------------------------------------------

create table ApiDBUserDataset.UD_NaFeatureExpression (
NA_FEAT_EXPRESSION_ID NOT NULL NUMBER(12),    
PROTOCOL_APP_NODE_ID  NOT NULL NUMBER(10),    
NA_FEATURE_ID         NOT NULL NUMBER(10),    
VALUE                          FLOAT(126),    
CONFIDENCE                     FLOAT(126),    
STANDARD_ERROR                 FLOAT(126),    
CATEGORICAL_VALUE              VARCHAR2(100), 
PERCENTILE_CHANNEL1            FLOAT(126),    
PERCENTILE_CHANNEL2            FLOAT(126),   
MODIFICATION_DATE     NOT NULL DATE          
USER_READ             NOT NULL NUMBER(1),     
USER_WRITE            NOT NULL NUMBER(1),     
GROUP_READ            NOT NULL NUMBER(1),     
GROUP_WRITE           NOT NULL NUMBER(1),     
OTHER_READ            NOT NULL NUMBER(1),     
OTHER_WRITE           NOT NULL NUMBER(1),     
ROW_USER_ID           NOT NULL NUMBER(12),    
ROW_GROUP_ID          NOT NULL NUMBER(4),     
ROW_PROJECT_ID        NOT NULL NUMBER(4),     
ROW_ALG_INVOCATION_ID NOT NULL NUMBER(12),    
 FOREIGN KEY (PROTOCOL_APP_NODE_ID) REFERENCES ApiDBUserDataset.UD_PROTOCOLAPPNODE,
 PRIMARY KEY (NA_FEAT_EXPRESSION_ID)
);

CREATE INDEX apiDBUserDataset.UD_NFE_idx1 ON apiDBUserDataset.UD_NaFeatureExpression (protocol_app_node_id) tablespace indx;
CREATE INDEX apiDBUserDataset.UD_NFE_idx2 ON apiDBUserDataset.UD_NaFeatureExpression (na_feature_id) tablespace indx;
CREATE unique INDEX apiDBUserDataset.UD_NFE_idx3 ON apiDBUserDataset.UD_NaFeatureExpression (na_feature_id, protocol_app_node_id) tablespace indx;

create sequence ApiDBUserDataset.UD_NaFeatureExpression_sq;

GRANT insert, select, update, delete ON ApiDBUserDataset.UD_NaFeatureExpression TO gus_w;
GRANT select ON ApiDBUserDataset.UD_NaFeatureExpression TO gus_r;
GRANT select ON ApiDBUserDataset.UD_NaFeatureExpression_sq TO gus_w;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'UD_NaFeatureExpression',
       'Standard', 'NA_FEAT_EXPRESSION_ID',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'UD_NaFeatureExpression' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);


---------------------------------------------------------------------------------

create table ApiDBUserDataset.UD_GeneId (
USER_DATASET_ID          NUMBER(10),     
gene_SOURCE_ID                             VARCHAR2(100),  
FOREIGN KEY (user_dataset_id) REFERENCES ApiDBUserDataset.InstalledUserDataset,
);

CREATE unique INDEX apiDBUserDataset.UD_GENEID_idx1 ON apiDBUserDataset.UD_geneid (user_dataset_id, gene_source_id) tablespace indx;

GRANT insert, select, update, delete ON ApiDBUserDataset.UD_GeneId TO gus_w;
GRANT select ON ApiDBUserDataset.UD_GeneId TO gus_r;



