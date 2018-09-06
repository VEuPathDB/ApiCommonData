create table ApiDBUserDatasets.UD_GeneId (
USER_DATASET_ID          NUMBER(20),     
gene_SOURCE_ID                             VARCHAR2(100),  
FOREIGN KEY (user_dataset_id) REFERENCES ApiDBUserDatasets.InstalledUserDataset
);

CREATE unique INDEX ApiDBUserDatasets.UD_GENEID_idx1 ON ApiDBUserDatasets.UD_geneid (user_dataset_id, gene_source_id) tablespace indx;

GRANT insert, select, update, delete ON ApiDBUserDatasets.UD_GeneId TO gus_w;
GRANT select ON ApiDBUserDatasets.UD_GeneId TO gus_r;

----------------------------------------------------------------------------
create table ApiDBUserDatasets.UD_PROTOCOLAPPNODE (
PROTOCOL_APP_NODE_ID         NUMBER(10) not null,     
TYPE_ID                               NUMBER(10),     
NAME                         VARCHAR2(200) not null,  
DESCRIPTION                           VARCHAR2(1000), 
URI                                   VARCHAR2(300),  
USER_DATASET_ID          NUMBER(20),     
SOURCE_ID                             VARCHAR2(100),  
SUBTYPE_ID                            NUMBER(10),     
TAXON_ID                              NUMBER(10),     
NODE_ORDER_NUM                        NUMBER(10),     
ISA_TYPE                              VARCHAR2(50),   
 FOREIGN KEY (user_dataset_id) REFERENCES ApiDBUserDatasets.InstalledUserDataset,
 PRIMARY KEY (protocol_app_node_id)
);

CREATE INDEX ApiDBUserDatasets.UD_PAN_idx1 ON ApiDBUserDatasets.UD_PROTOCOLAPPNODE (type_id) tablespace indx;
CREATE INDEX ApiDBUserDatasets.UD_PAN_idx2 ON ApiDBUserDatasets.UD_PROTOCOLAPPNODE (user_dataset_id) tablespace indx;
CREATE INDEX ApiDBUserDatasets.UD_PAN_idx3 ON ApiDBUserDatasets.UD_PROTOCOLAPPNODE (subtype_id) tablespace indx;
CREATE INDEX ApiDBUserDatasets.UD_PAN_idx4 ON ApiDBUserDatasets.UD_PROTOCOLAPPNODE (taxon_id, protocol_app_node_id) tablespace indx;

create sequence ApiDBUserDatasets.UD_ProtocolAppNode_sq;

GRANT insert, select, update, delete ON ApiDBUserDatasets.UD_ProtocolAppNode TO gus_w;
GRANT select ON ApiDBUserDatasets.UD_ProtocolAppNode TO gus_r;
GRANT select ON ApiDBUserDatasets.UD_ProtocolAppNode_sq TO gus_w;

-----------------------------------------------------------------------------------------------------

create table ApiDBUserDatasets.UD_NaFeatureExpression (
NA_FEAT_EXPRESSION_ID NUMBER(12) NOT NULL,    
PROTOCOL_APP_NODE_ID  NUMBER(10) NOT NULL,    
NA_FEATURE_ID         NUMBER(10) NOT NULL,    
VALUE                          FLOAT(126),    
CONFIDENCE                     FLOAT(126),    
STANDARD_ERROR                 FLOAT(126),    
CATEGORICAL_VALUE              VARCHAR2(100), 
PERCENTILE_CHANNEL1            FLOAT(126),    
PERCENTILE_CHANNEL2            FLOAT(126),   
 FOREIGN KEY (PROTOCOL_APP_NODE_ID) REFERENCES ApiDBUserDatasets.UD_PROTOCOLAPPNODE,
 PRIMARY KEY (NA_FEAT_EXPRESSION_ID)
);

CREATE INDEX ApiDBUserDatasets.UD_NFE_idx1 ON ApiDBUserDatasets.UD_NaFeatureExpression (protocol_app_node_id) tablespace indx;
CREATE INDEX ApiDBUserDatasets.UD_NFE_idx2 ON ApiDBUserDatasets.UD_NaFeatureExpression (na_feature_id) tablespace indx;
CREATE unique INDEX ApiDBUserDatasets.UD_NFE_idx3 ON ApiDBUserDatasets.UD_NaFeatureExpression (na_feature_id, protocol_app_node_id) tablespace indx;

create sequence ApiDBUserDatasets.UD_NaFeatureExpression_sq;

GRANT insert, select, update, delete ON ApiDBUserDatasets.UD_NaFeatureExpression TO gus_w;
GRANT select ON ApiDBUserDatasets.UD_NaFeatureExpression TO gus_r;
GRANT select ON ApiDBUserDatasets.UD_NaFeatureExpression_sq TO gus_w;

--------------------------------------------------------------------------------

create table ApiDBUserDatasets.Profile (
 profile_id                   number(20),
 user_dataset_id               number(20),
 dataset_type                 varchar2(50),
 dataset_subtype              varchar2(50),
 profile_type                 varchar2(20),
 source_id                    varchar2(400),
-- profile_study_id             number(5),
-- profile_set_name             varchar2(400),
 profile_set_suffix           varchar2(50),
 profile_as_string            varchar2(4000),
 max_value                    number,
 min_value                    number,
 max_timepoint                varchar2(200),
 min_timepoint                varchar2(200),
 foreign key (user_dataset_id) references ApiDBUserDatasets.InstalledUserDataset,
 primary key (profile_id)
);

create index ApiDBUserDatasets.prf_idx1
  on ApiDBUserDatasets.Profile
     (user_dataset_id, profile_id)
  tablespace indx;

create sequence ApiDBUserDatasets.profile_sq;

grant insert, select, update, delete on ApiDBUserDatasets.Profile to gus_w;
grant select on ApiDBUserDatasets.Profile to gus_r;
grant select on ApiDBUserDatasets.profile_sq to gus_w;

--------------------------------------------------------------------------------
exit;



