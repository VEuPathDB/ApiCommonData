create table ApiDBUserDatasets.UD_GeneId (
USER_DATASET_ID          NUMBER(20),     
gene_SOURCE_ID                             VARCHAR2(100),  
FOREIGN KEY (user_dataset_id) REFERENCES ApiDBUserDatasets.InstalledUserDataset
);

CREATE unique INDEX ApiDBUserDatasets.UD_GENEID_idx1 ON ApiDBUserDatasets.UD_geneid (user_dataset_id, gene_source_id) tablespace indx;

GRANT insert, select, update, delete ON ApiDBUserDatasets.UD_GeneId TO gus_w;
GRANT select ON ApiDBUserDatasets.UD_GeneId TO gus_r;

----------------------------------------------------------------------------

create table ApiDBUserDatasets.UD_ProfileSet (
 profile_set_id number(20),
 user_dataset_id number(20),
 name varchar2(200) not null,  
 foreign key (user_dataset_id) references ApiDBUserDatasets.InstalledUserDataset,
 primary key (profile_set_id)
);
 
create index ApiDBUserDatasets.pset_idx1
  on ApiDBUserDatasets.UD_ProfileSet
     (profile_set_id, user_dataset_id, name)
  tablespace indx;

create sequence ApiDBUserDatasets.UD_profileset_sq;

grant insert, select, update, delete on ApiDBUserDatasets.UD_ProfileSet to gus_w;
grant select on ApiDBUserDatasets.UD_ProfileSet to gus_r;
grant select on ApiDBUserDatasets.UD_profileSet_sq to gus_w;

----------------------------------------------------------------------------
create table ApiDBUserDatasets.UD_ProtocolAppNode (
PROTOCOL_APP_NODE_ID                  NUMBER(10) not null,     
TYPE_ID                               NUMBER(10),     
NAME                                  VARCHAR2(200) not null,  
DESCRIPTION                           VARCHAR2(1000), 
URI                                   VARCHAR2(300),  
profile_set_id                        NUMBER(20),     
SOURCE_ID                             VARCHAR2(100),  
SUBTYPE_ID                            NUMBER(10),     
TAXON_ID                              NUMBER(10),     
NODE_ORDER_NUM                        NUMBER(10),     
ISA_TYPE                              VARCHAR2(50),   
FOREIGN KEY (profile_set_id) REFERENCES ApiDBUserDatasets.UD_profileset,
PRIMARY KEY (protocol_app_node_id)
);

CREATE INDEX ApiDBUserDatasets.UD_PAN_idx1 ON ApiDBUserDatasets.UD_PROTOCOLAPPNODE (type_id) tablespace indx;
CREATE INDEX ApiDBUserDatasets.UD_PAN_idx2 ON ApiDBUserDatasets.UD_PROTOCOLAPPNODE (profile_set_id) tablespace indx;
CREATE INDEX ApiDBUserDatasets.UD_PAN_idx3 ON ApiDBUserDatasets.UD_PROTOCOLAPPNODE (subtype_id) tablespace indx;
CREATE INDEX ApiDBUserDatasets.UD_PAN_idx4 ON ApiDBUserDatasets.UD_PROTOCOLAPPNODE (taxon_id, protocol_app_node_id) tablespace indx;
CREATE INDEX apidbUserDatasets.ud_pan_idx5 on apidbUserDatasets.ud_ProtocolAppNode (protocol_app_node_id, profile_set_id, name);


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

CREATE INDEX ApiDBUserDatasets.UD_NFE_idx1 ON ApiDBUserDatasets.UD_NaFeatureExpression (protocol_app_node_id, na_feature_id, value) tablespace indx;
CREATE INDEX ApiDBUserDatasets.UD_NFE_idx2 ON ApiDBUserDatasets.UD_NaFeatureExpression (na_feature_id) tablespace indx;
CREATE unique INDEX ApiDBUserDatasets.UD_NFE_idx3 ON ApiDBUserDatasets.UD_NaFeatureExpression (na_feature_id, protocol_app_node_id, value) tablespace indx;

create sequence ApiDBUserDatasets.UD_NaFeatureExpression_sq;

GRANT insert, select, update, delete ON ApiDBUserDatasets.UD_NaFeatureExpression TO gus_w;
GRANT select ON ApiDBUserDatasets.UD_NaFeatureExpression TO gus_r;
GRANT select ON ApiDBUserDatasets.UD_NaFeatureExpression_sq TO gus_w;

--------------------------------------------------------------------------------
CREATE TABLE apidbUserDatasets.ud_NaFeatureDiffResult (
  na_feat_diff_res_id  NUMBER(12),
  protocol_app_node_id NUMBER(10),
  na_feature_id        NUMBER(10),
  mean1                FLOAT(126),
  sd1                  FLOAT(126),
  mean2                FLOAT(126),
  sd2                  FLOAT(126),
  fdr                  FLOAT(126),
  fold_change          FLOAT(126),
  test_statistic       FLOAT(126),
  p_value              FLOAT(126),
  adj_p_value          FLOAT(126),
  q_value              FLOAT(126),
  confidence_up        FLOAT(126),
  confidence_down      FLOAT(126),
  confidence           FLOAT(126),
  z_score              FLOAT(12),
  is_significant       NUMBER(1),
  FOREIGN KEY (protocol_app_node_id) REFERENCES apidbUserDatasets.ud_ProtocolAppNode,
  PRIMARY KEY (na_feat_diff_res_id)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON apidbUserDatasets.ud_NaFeatureDiffResult TO gus_w;
GRANT SELECT ON apidbUserDatasets.ud_NaFeatureDiffResult TO gus_r;

CREATE SEQUENCE apidbUserDatasets.ud_NaFeatureDiffResult_sq;
GRANT SELECT ON apidbUserDatasets.ud_NaFeatureDiffResult_sq TO gus_w;
--------------------------------------------------------------------------------

exit;



