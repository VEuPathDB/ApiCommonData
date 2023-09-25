create table VDI_DATASETS_&1..UD_GeneId (
USER_DATASET_ID          VARCHAR2(32),
gene_SOURCE_ID                             VARCHAR2(100),
FOREIGN KEY (user_dataset_id) REFERENCES VDI_CONTROL_&1..dataset(dataset_id)
);

CREATE unique INDEX VDI_DATASETS_&1..UD_GENEID_idx1 ON VDI_DATASETS_&1..UD_geneid (user_dataset_id, gene_source_id) tablespace indx;

GRANT insert, select, update, delete ON VDI_DATASETS_&1..UD_GeneId TO gus_w;
GRANT select ON VDI_DATASETS_&1..UD_GeneId TO gus_r;

----------------------------------------------------------------------------

create table VDI_DATASETS_&1..UD_ProfileSet (
 profile_set_id  number(20),
 user_dataset_id varchar2(32),
 name            varchar2(200) not null,
 unit            varchar2(4),
 foreign key (user_dataset_id) references VDI_CONTROL_&1..DATASET(dataset_id),
 primary key (profile_set_id)
);

create index VDI_DATASETS_&1..pset_idx1
  on VDI_DATASETS_&1..UD_ProfileSet
     (profile_set_id, user_dataset_id, name, unit)
  tablespace indx;

create sequence VDI_DATASETS_&1..UD_profileset_sq;

grant insert, select, update, delete on VDI_DATASETS_&1..UD_ProfileSet to gus_w;
grant select on VDI_DATASETS_&1..UD_ProfileSet to gus_r;
grant select on VDI_DATASETS_&1..UD_profileSet_sq to gus_w;

----------------------------------------------------------------------------
create table VDI_DATASETS_&1..UD_ProtocolAppNode (
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
FOREIGN KEY (profile_set_id) REFERENCES VDI_DATASETS_&1..UD_profileset,
PRIMARY KEY (protocol_app_node_id)
);

CREATE INDEX VDI_DATASETS_&1..UD_PAN_idx1 ON VDI_DATASETS_&1..UD_PROTOCOLAPPNODE (type_id) tablespace indx;
CREATE INDEX VDI_DATASETS_&1..UD_PAN_idx2 ON VDI_DATASETS_&1..UD_PROTOCOLAPPNODE (profile_set_id) tablespace indx;
CREATE INDEX VDI_DATASETS_&1..UD_PAN_idx3 ON VDI_DATASETS_&1..UD_PROTOCOLAPPNODE (subtype_id) tablespace indx;
CREATE INDEX VDI_DATASETS_&1..UD_PAN_idx4 ON VDI_DATASETS_&1..UD_PROTOCOLAPPNODE (taxon_id, protocol_app_node_id) tablespace indx;
CREATE INDEX VDI_DATASETS_&1..ud_pan_idx5 on VDI_DATASETS_&1..ud_ProtocolAppNode (protocol_app_node_id, profile_set_id, name);


create sequence VDI_DATASETS_&1..UD_ProtocolAppNode_sq;

GRANT insert, select, update, delete ON VDI_DATASETS_&1..UD_ProtocolAppNode TO gus_w;
GRANT select ON VDI_DATASETS_&1..UD_ProtocolAppNode TO gus_r;
GRANT select ON VDI_DATASETS_&1..UD_ProtocolAppNode_sq TO gus_w;

-----------------------------------------------------------------------------------------------------

create table VDI_DATASETS_&1..UD_NaFeatureExpression (
  na_feat_expression_id NUMBER(12) NOT NULL,
  protocol_app_node_id  NUMBER(10) NOT NULL,
  na_feature_id         NUMBER(10) NOT NULL,
  value                 FLOAT(126),
  confidence            FLOAT(126),
  standard_error        FLOAT(126),
  categorical_value     VARCHAR2(100),
  percentile_channel1   FLOAT(126),
  percentile_channel2   FLOAT(126),
  FOREIGN KEY (protocol_app_node_id) REFERENCES VDI_DATASETS_&1..ud_ProtocolAppNode,
  PRIMARY KEY (na_feat_expression_id)
);

CREATE INDEX VDI_DATASETS_&1..UD_NFE_idx1 ON VDI_DATASETS_&1..UD_NaFeatureExpression (protocol_app_node_id, na_feature_id, value) tablespace indx;
CREATE INDEX VDI_DATASETS_&1..UD_NFE_idx2 ON VDI_DATASETS_&1..UD_NaFeatureExpression (na_feature_id) tablespace indx;
CREATE unique INDEX VDI_DATASETS_&1..UD_NFE_idx3 ON VDI_DATASETS_&1..UD_NaFeatureExpression (na_feature_id, protocol_app_node_id, value) tablespace indx;

create sequence VDI_DATASETS_&1..UD_NaFeatureExpression_sq;

GRANT insert, select, update, delete ON VDI_DATASETS_&1..UD_NaFeatureExpression TO gus_w;
GRANT select ON VDI_DATASETS_&1..UD_NaFeatureExpression TO gus_r;
GRANT select ON VDI_DATASETS_&1..UD_NaFeatureExpression_sq TO gus_w;

--------------------------------------------------------------------------------
CREATE TABLE VDI_DATASETS_&1..ud_NaFeatureDiffResult (
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
  FOREIGN KEY (protocol_app_node_id) REFERENCES VDI_DATASETS_&1..ud_ProtocolAppNode,
  PRIMARY KEY (na_feat_diff_res_id)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON VDI_DATASETS_&1..ud_NaFeatureDiffResult TO gus_w;
GRANT SELECT ON VDI_DATASETS_&1..ud_NaFeatureDiffResult TO gus_r;

CREATE SEQUENCE VDI_DATASETS_&1..ud_NaFeatureDiffResult_sq;
GRANT SELECT ON VDI_DATASETS_&1..ud_NaFeatureDiffResult_sq TO gus_w;

--------------------------------------------------------------------------------
-- based on datasetPresenters
-- intended for summary statistics etc. created during installation
-- WDK also has access to display values from IRODS: name, summary, and description
-- These are editable by the user, so there is no consistent way to keep them here

create table VDI_DATASETS_&1..UD_Presenter (
  user_dataset_id varchar2(32) not null,
  property_name varchar2(200) not null,
  property_value varchar2(200) not null,
  foreign key (user_dataset_id) references VDI_CONTROL_&1..DATASET(dataset_id),
  unique(user_dataset_id, property_name)
);

grant insert, select, update, delete on VDI_DATASETS_&1..UD_Presenter to gus_w;
grant select on VDI_DATASETS_&1..UD_Presenter to gus_r;


create table VDI_DATASETS_&1..UD_Sample (
user_dataset_id                       VARCHAR2(32) not null,
sample_id                             NUMBER(10) not null,
name                                  VARCHAR2(200) not null,
display_name                                  VARCHAR2(200),
FOREIGN KEY (user_dataset_id) REFERENCES VDI_CONTROL_&1..DATASET(dataset_id),
PRIMARY KEY (sample_id),
UNIQUE (name)
);
create sequence VDI_DATASETS_&1..UD_Sample_sq;

GRANT insert, select, update, delete ON VDI_DATASETS_&1..UD_Sample TO gus_w;
GRANT select ON VDI_DATASETS_&1..UD_Sample TO gus_r;
GRANT select ON VDI_DATASETS_&1..UD_Sample_sq TO gus_w;

-- -- potentially unnecessary: it is meant to be for SampleTables.Characteristics_table, but with the smaller amount of test data Oracle does full table access anyway
-- create index VDI_DATASETS_&1..ud_Sample_ud_idx on VDI_DATASETS_&1..ud_Sample (user_dataset_id) tablespace indx;

-- -- a bit like apidbtuning.propertytype
-- -- not sure if I want these:
-- --    parent => $propertyType,
-- --    parent_source_id => $propertyTypeOntologyTerm,
-- --    description => "$property: $valuesSummary",
-- -- skipped: property_source_id, I think it's the ontology term for property
-- create table VDI_DATASETS_&1..ud_Property (
--   user_dataset_id varchar2(32) not null,
--   PROPERTY_ID                                        NUMBER(10) not null,
--   PROPERTY                                           VARCHAR2(400),
--   TYPE                                               VARCHAR2(6),
--   FILTER                                             VARCHAR2(10),
--   DISTINCT_VALUES                                    NUMBER,
--   PARENT                                             VARCHAR2(200),
--   PARENT_SOURCE_ID                                   VARCHAR2(100),
--   DESCRIPTION                                        VARCHAR2(400),
--   FOREIGN KEY (user_dataset_id) REFERENCES VDI_CONTROL_&1..DATASET(dataset_id),
--   PRIMARY KEY (property_id)
-- );
-- GRANT INSERT, SELECT, UPDATE, DELETE ON VDI_DATASETS_&1..ud_Property TO gus_w;
-- GRANT SELECT ON VDI_DATASETS_&1..ud_Property TO gus_r;

-- CREATE SEQUENCE VDI_DATASETS_&1..ud_Property_sq;
-- GRANT SELECT ON VDI_DATASETS_&1..ud_Property_sq TO gus_w;

-- -- potentially unnecessary: it is meant to be for SampleTables.Characteristics_table, but with the smaller amount of test data Oracle does full table access anyway
-- create index VDI_DATASETS_&1..ud_Property_ud_idx on VDI_DATASETS_&1..ud_Property (user_dataset_id) tablespace indx;

-- -- a bit like apidbtuning.metadata
-- -- user_dataset_id not needed but makes deleting simpler
-- create table VDI_DATASETS_&1..ud_SampleDetail (
--  user_dataset_id varchar2(32) not null,
--   sample_id                      NUMBER(10) NOT NULL,
--   PROPERTY_ID                                        NUMBER(10) not null,
--   DATE_VALUE                                         DATE,
--   NUMBER_VALUE                                       NUMBER,
--   STRING_VALUE                                       VARCHAR2(1000),
--   FOREIGN KEY (user_dataset_id) REFERENCES VDI_CONTROL_&1..DATASET(dataset_id),
--   FOREIGN KEY (sample_id) REFERENCES VDI_DATASETS_&1..UD_Sample (sample_id),
--   FOREIGN KEY (property_id) REFERENCES VDI_DATASETS_&1..ud_Property (property_id)
-- );
-- -- potentially unnecessary: it is meant to be for SampleTables.Characteristics_table, but with the smaller amount of test data Oracle does full table access anyway
-- create index VDI_DATASETS_&1..ud_SampleDetail_sid_idx on VDI_DATASETS_&1..ud_SampleDetail (sample_id) tablespace indx;
-- create index VDI_DATASETS_&1..ud_SampleDetail_ud_idx on VDI_DATASETS_&1..ud_SampleDetail (user_dataset_id) tablespace indx;
-- create index VDI_DATASETS_&1..ud_SampleDetail_pid_idx on VDI_DATASETS_&1..ud_SampleDetail (property_id) tablespace indx;

-- GRANT INSERT, SELECT, UPDATE, DELETE ON VDI_DATASETS_&1..ud_SampleDetail TO gus_w;
-- GRANT SELECT ON VDI_DATASETS_&1..ud_SampleDetail TO gus_r;
-- -- based on apidbtuning.TaxonRelativeAbundance
-- -- without the extra protocol_app_node_id
-- -- wider columns: allows 200 characters per term to better handle whatever people try to store in there
-- -- lineage is 1406 chars long to match the max width of all columns plus six semicolons
-- CREATE TABLE VDI_DATASETS_&1..ud_Abundance (
--  user_dataset_id varchar2(32) not null,
--  SAMPLE_ID                      NUMBER(10) NOT NULL,
--  LINEAGE                                  VARCHAR2(1406) NOT NULL,
--  RELATIVE_ABUNDANCE                                 FLOAT(126),
--  ABSOLUTE_ABUNDANCE                                 NUMBER(20),
--  NCBI_TAX_ID                                        NUMBER(10),
--  KINGDOM                                            VARCHAR2(200),
--  PHYLUM                                             VARCHAR2(200),
--  CLASS                                              VARCHAR2(200),
--  RANK_ORDER                                         VARCHAR2(200),
--  FAMILY                                             VARCHAR2(200),
--  GENUS                                              VARCHAR2(200),
--  SPECIES                                            VARCHAR2(200),
--  FOREIGN KEY (user_dataset_id) REFERENCES VDI_CONTROL_&1..DATASET(dataset_id),
--  FOREIGN KEY (SAMPLE_ID) REFERENCES VDI_DATASETS_&1..ud_Sample (sample_id)
-- );
-- GRANT INSERT, SELECT, UPDATE, DELETE ON VDI_DATASETS_&1..ud_Abundance TO gus_w;
-- GRANT SELECT ON VDI_DATASETS_&1..ud_Abundance TO gus_r;

-- create index VDI_DATASETS_&1..ud_Abundance_name_idx on VDI_DATASETS_&1..ud_Abundance (sample_id) tablespace indx;

-- -- based on apidbtuning.TaxonAbundance
-- -- term -> taxon_name
-- -- added lineage since taxon_name may not be unique (Incertae Sedis in SILVA)
-- -- category -> taxon_level_name

-- CREATE TABLE  VDI_DATASETS_&1..ud_AggregatedAbundance (
--  user_dataset_id varchar2(32) not null,
--  SAMPLE_ID                      NUMBER(10) NOT NULL,
--  TAXON_LEVEL_NAME                                           VARCHAR2(10),
--  TAXON_LEVEL                                        NUMBER,
--  TAXON_NAME                                               VARCHAR2(200) NOT NULL,
--  LINEAGE                                               VARCHAR2(1406) NOT NULL,
--  RELATIVE_ABUNDANCE                                 FLOAT(126),
--  ABSOLUTE_ABUNDANCE                                 NUMBER(20),
--  FOREIGN KEY (user_dataset_id) REFERENCES VDI_CONTROL_&1..DATASET(dataset_id),
--  FOREIGN KEY (SAMPLE_ID) REFERENCES VDI_DATASETS_&1..ud_Sample (sample_id)
-- );
-- GRANT INSERT, SELECT, UPDATE, DELETE ON VDI_DATASETS_&1..ud_AggregatedAbundance TO gus_w;
-- GRANT SELECT ON VDI_DATASETS_&1..ud_AggregatedAbundance TO gus_r;

-- create index VDI_DATASETS_&1..ud_AggregatedAbundance_name_idx on VDI_DATASETS_&1..ud_AggregatedAbundance (sample_id) tablespace indx;
-- create index VDI_DATASETS_&1..ud_AggregatedAbundance_ud_idx on VDI_DATASETS_&1..ud_AggregatedAbundance (user_dataset_id) tablespace indx;



-----------------------------------------------------------


exit;
