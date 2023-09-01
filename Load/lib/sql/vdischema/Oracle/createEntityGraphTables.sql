CREATE TABLE VDI_DATASETS_&1..Study (
 USER_DATASET_ID     CHAR(32),     
 study_id            NUMBER(12) NOT NULL,
 stable_id                         VARCHAR2(200) NOT NULL,
 external_database_release_id number(10) NOT NULL,
 internal_abbrev              varchar2(75),
 max_attr_length              number(4),
 modification_date            DATE NOT NULL,
 PRIMARY KEY (study_id),
 CONSTRAINT unique_stable_id UNIQUE (stable_id),
 FOREIGN KEY (user_dataset_id) REFERENCES VDI_CONTROL_&1..dataset(dataset_id)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON VDI_DATASETS_&1..Study TO gus_w;
GRANT SELECT ON VDI_DATASETS_&1..Study TO gus_r;

CREATE SEQUENCE VDI_DATASETS_&1..Study_sq;
GRANT SELECT ON VDI_DATASETS_&1..Study_sq TO gus_w;
GRANT SELECT ON VDI_DATASETS_&1..Study_sq TO gus_r;

CREATE INDEX VDI_DATASETS_&1..study_ix_1 ON VDI_DATASETS_&1..study (external_database_release_id, stable_id, internal_abbrev, study_id) TABLESPACE indx;

-----------------------------------------------------------

CREATE TABLE VDI_DATASETS_&1..EntityType (
 entity_type_id            NUMBER(12) NOT NULL,
 name                      VARCHAR2(200) NOT NULL,
 type_id                   NUMBER(10),
 isa_type                     VARCHAR2(50),
 study_id            NUMBER(12) NOT NULL,
 internal_abbrev              VARCHAR2(50) NOT NULL,
 cardinality                  NUMBER(38,0),
 FOREIGN KEY (study_id) REFERENCES VDI_DATASETS_&1..study,
 PRIMARY KEY (entity_type_id)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON VDI_DATASETS_&1..EntityType TO gus_w;
GRANT SELECT ON VDI_DATASETS_&1..EntityType TO gus_r;

CREATE SEQUENCE VDI_DATASETS_&1..EntityType_sq;
GRANT SELECT ON VDI_DATASETS_&1..EntityType_sq TO gus_w;
GRANT SELECT ON VDI_DATASETS_&1..EntityType_sq TO gus_r;

CREATE UNIQUE INDEX VDI_DATASETS_&1..entitytype_ix_1 ON VDI_DATASETS_&1..entitytype (study_id, entity_type_id) TABLESPACE indx;
CREATE UNIQUE INDEX VDI_DATASETS_&1..entitytype_ix_2 ON VDI_DATASETS_&1..entitytype (type_id, entity_type_id) TABLESPACE indx;
CREATE UNIQUE INDEX VDI_DATASETS_&1..entitytype_ix_3 ON VDI_DATASETS_&1..entitytype (study_id, internal_abbrev) TABLESPACE indx;

-----------------------------------------------------------

CREATE TABLE VDI_DATASETS_&1..ProcessType (
 process_type_id            NUMBER(12) NOT NULL,
 name                         VARCHAR2(200) NOT NULL,
 description                  VARCHAR2(4000),
 type_id                      NUMBER(10),
 PRIMARY KEY (process_type_id)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON VDI_DATASETS_&1..ProcessType TO gus_w;
GRANT SELECT ON VDI_DATASETS_&1..ProcessType TO gus_r;

CREATE SEQUENCE VDI_DATASETS_&1..ProcessType_sq;
GRANT SELECT ON VDI_DATASETS_&1..ProcessType_sq TO gus_w;
GRANT SELECT ON VDI_DATASETS_&1..ProcessType_sq TO gus_r;

CREATE INDEX VDI_DATASETS_&1..processtype_ix_1 ON VDI_DATASETS_&1..processtype (type_id, process_type_id) TABLESPACE indx;

-----------------------------------------------------------

CREATE TABLE VDI_DATASETS_&1..EntityAttributes (
 entity_attributes_id         NUMBER(12) NOT NULL,
 stable_id                         VARCHAR2(200) NOT NULL,
 entity_type_id               NUMBER(12) NOT NULL,
 atts                         CLOB,
 PRIMARY KEY (entity_attributes_id),
 FOREIGN KEY (entity_type_id) REFERENCES VDI_DATASETS_&1..EntityType,
 CONSTRAINT ensure_va_json CHECK (atts is json)
);

-- 
--CREATE SEARCH INDEX VDI_DATASETS_&1..va_search_ix ON VDI_DATASETS_&1..entityattributes (atts) FOR JSON;

CREATE INDEX VDI_DATASETS_&1..entityattributes_ix_1 ON VDI_DATASETS_&1..entityattributes (entity_type_id, entity_attributes_id) TABLESPACE indx;

GRANT INSERT, SELECT, UPDATE, DELETE ON VDI_DATASETS_&1..EntityAttributes TO gus_w;
GRANT SELECT ON VDI_DATASETS_&1..EntityAttributes TO gus_r;

CREATE SEQUENCE VDI_DATASETS_&1..EntityAttributes_sq;
GRANT SELECT ON VDI_DATASETS_&1..EntityAttributes_sq TO gus_w;
GRANT SELECT ON VDI_DATASETS_&1..EntityAttributes_sq TO gus_r;

-----------------------------------------------------------

CREATE TABLE VDI_DATASETS_&1..EntityClassification (
 entity_classification_id         NUMBER(12) NOT NULL,
 entity_attributes_id         NUMBER(12) NOT NULL,
 entity_type_id               NUMBER(12) NOT NULL,
 FOREIGN KEY (entity_type_id) REFERENCES VDI_DATASETS_&1..EntityType,
 FOREIGN KEY (entity_attributes_id) REFERENCES VDI_DATASETS_&1..EntityAttributes,
 PRIMARY KEY (entity_classification_id)
);

CREATE INDEX VDI_DATASETS_&1..entityclassification_ix_1 ON VDI_DATASETS_&1..entityclassification (entity_type_id, entity_attributes_id) TABLESPACE indx;
CREATE INDEX VDI_DATASETS_&1..entityclassification_ix_2 ON VDI_DATASETS_&1..entityclassification (entity_attributes_id, entity_type_id) TABLESPACE indx;

GRANT INSERT, SELECT, UPDATE, DELETE ON VDI_DATASETS_&1..EntityClassification TO gus_w;
GRANT SELECT ON VDI_DATASETS_&1..EntityClassification TO gus_r;

CREATE SEQUENCE VDI_DATASETS_&1..EntityClassification_sq;
GRANT SELECT ON VDI_DATASETS_&1..EntityClassification_sq TO gus_w;
GRANT SELECT ON VDI_DATASETS_&1..EntityClassification_sq TO gus_r;

-----------------------------------------------------------

CREATE TABLE VDI_DATASETS_&1..ProcessAttributes (
 process_attributes_id           NUMBER(12) NOT NULL,
 process_type_id                NUMBER(12) NOT NULL,
 in_entity_id                 NUMBER(12) NOT NULL,
 out_entity_id                NUMBER(12) NOT NULL,
 atts                         CLOB,
 FOREIGN KEY (in_entity_id) REFERENCES VDI_DATASETS_&1..entityattributes,
 FOREIGN KEY (out_entity_id) REFERENCES VDI_DATASETS_&1..entityattributes,
 FOREIGN KEY (process_type_id) REFERENCES VDI_DATASETS_&1..processtype,
 PRIMARY KEY (process_attributes_id),
 CONSTRAINT ensure_ea_json CHECK (atts is json)   
);

CREATE INDEX VDI_DATASETS_&1..ea_in_ix ON VDI_DATASETS_&1..processattributes (in_entity_id, out_entity_id, process_attributes_id) tablespace indx;
CREATE INDEX VDI_DATASETS_&1..ea_out_ix ON VDI_DATASETS_&1..processattributes (out_entity_id, in_entity_id, process_attributes_id) tablespace indx;

CREATE INDEX VDI_DATASETS_&1..ea_ix_1 ON VDI_DATASETS_&1..processattributes (process_type_id, process_attributes_id) TABLESPACE indx;

GRANT INSERT, SELECT, UPDATE, DELETE ON VDI_DATASETS_&1..ProcessAttributes TO gus_w;
GRANT SELECT ON VDI_DATASETS_&1..ProcessAttributes TO gus_r;

CREATE SEQUENCE VDI_DATASETS_&1..ProcessAttributes_sq;
GRANT SELECT ON VDI_DATASETS_&1..ProcessAttributes_sq TO gus_w;
GRANT SELECT ON VDI_DATASETS_&1..ProcessAttributes_sq TO gus_r;

-----------------------------------------------------------

CREATE TABLE VDI_DATASETS_&1..EntityTypeGraph (
 entity_type_graph_id           NUMBER(12) NOT NULL,
 study_id                       NUMBER(12) NOT NULL,
 study_stable_id                varchar2(200),
 parent_stable_id             varchar2(255),
 parent_id                    NUMBER(12),
 stable_id                    varchar2(255),
 entity_type_id                NUMBER(12) NOT NULL,
 display_name                 VARCHAR2(200) NOT NULL,
 display_name_plural          VARCHAR2(200),
 description                  VARCHAR2(4000),
 internal_abbrev              VARCHAR2(50) NOT NULL,
 has_attribute_collections    NUMBER(1),
 is_many_to_one_with_parent   NUMBER(1),
 cardinality                  NUMBER(38,0),
 FOREIGN KEY (study_id) REFERENCES VDI_DATASETS_&1..study,
 FOREIGN KEY (parent_id) REFERENCES VDI_DATASETS_&1..entitytype,
 FOREIGN KEY (entity_type_id) REFERENCES VDI_DATASETS_&1..entitytype,
 PRIMARY KEY (entity_type_graph_id)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON VDI_DATASETS_&1..EntityTypeGraph TO gus_w;
GRANT SELECT ON VDI_DATASETS_&1..EntityTypeGraph TO gus_r;

CREATE SEQUENCE VDI_DATASETS_&1..EntityTypeGraph_sq;
GRANT SELECT ON VDI_DATASETS_&1..EntityTypeGraph_sq TO gus_w;
GRANT SELECT ON VDI_DATASETS_&1..EntityTypeGraph_sq TO gus_r;

CREATE INDEX VDI_DATASETS_&1..entitytypegraph_ix_1 ON VDI_DATASETS_&1..entitytypegraph (study_id, entity_type_id, parent_id, entity_type_graph_id) TABLESPACE indx;
CREATE INDEX VDI_DATASETS_&1..entitytypegraph_ix_2 ON VDI_DATASETS_&1..entitytypegraph (parent_id, entity_type_graph_id) TABLESPACE indx;
CREATE INDEX VDI_DATASETS_&1..entitytypegraph_ix_3 ON VDI_DATASETS_&1..entitytypegraph (entity_type_id, entity_type_graph_id) TABLESPACE indx;



-----------------------------------------------------------

CREATE TABLE VDI_DATASETS_&1..AttributeUnit (
 attribute_unit_id                NUMBER(12) NOT NULL,
 entity_type_id                      NUMBER(12) NOT NULL,
 attr_ontology_term_id               NUMBER(10) NOT NULL,
 unit_ontology_term_id               NUMBER(10) NOT NULL,
 FOREIGN KEY (entity_type_id) REFERENCES VDI_DATASETS_&1..EntityType,
 PRIMARY KEY (attribute_unit_id)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON VDI_DATASETS_&1..AttributeUnit TO gus_w;
GRANT SELECT ON VDI_DATASETS_&1..AttributeUnit TO gus_r;

CREATE SEQUENCE VDI_DATASETS_&1..AttributeUnit_sq;
GRANT SELECT ON VDI_DATASETS_&1..AttributeUnit_sq TO gus_w;
GRANT SELECT ON VDI_DATASETS_&1..AttributeUnit_sq TO gus_r;

CREATE INDEX VDI_DATASETS_&1..attributeunit_ix_1 ON VDI_DATASETS_&1..attributeunit (entity_type_id, attr_ontology_term_id, unit_ontology_term_id, attribute_unit_id) TABLESPACE indx;
CREATE INDEX VDI_DATASETS_&1..attributeunit_ix_2 ON VDI_DATASETS_&1..attributeunit (attr_ontology_term_id, attribute_unit_id) TABLESPACE indx;
CREATE INDEX VDI_DATASETS_&1..attributeunit_ix_3 ON VDI_DATASETS_&1..attributeunit (unit_ontology_term_id, attribute_unit_id) TABLESPACE indx;


-----------------------------------------------------------


CREATE TABLE VDI_DATASETS_&1..ProcessTypeComponent (
 process_type_component_id       NUMBER(12) NOT NULL,
 process_type_id                 NUMBER(12) NOT NULL,
 component_id                 NUMBER(12) NOT NULL,
 order_num                    NUMBER(2) NOT NULL,
 FOREIGN KEY (process_type_id) REFERENCES VDI_DATASETS_&1..ProcessType,
 FOREIGN KEY (component_id) REFERENCES VDI_DATASETS_&1..ProcessType,
 PRIMARY KEY (process_type_component_id)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON VDI_DATASETS_&1..ProcessTypeComponent TO gus_w;
GRANT SELECT ON VDI_DATASETS_&1..ProcessTypeComponent TO gus_r;

CREATE SEQUENCE VDI_DATASETS_&1..ProcessTypeComponent_sq;
GRANT SELECT ON VDI_DATASETS_&1..ProcessTypeComponent_sq TO gus_w;
GRANT SELECT ON VDI_DATASETS_&1..ProcessTypeComponent_sq TO gus_r;

CREATE INDEX VDI_DATASETS_&1..ptc_ix_1 ON VDI_DATASETS_&1..processtypecomponent (process_type_id, component_id, order_num, process_type_component_id) TABLESPACE indx;
CREATE INDEX VDI_DATASETS_&1..ptc_ix_2 ON VDI_DATASETS_&1..processtypecomponent (component_id, process_type_component_id) TABLESPACE indx;


-----------------------------------------------------------


CREATE TABLE VDI_DATASETS_&1..Attribute (
  attribute_id                  NUMBER(12) NOT NULL,
  entity_type_id                NUMBER(12) not null,
  entity_type_stable_id         varchar2(255),
  process_type_id                 NUMBER(12),
  ontology_term_id         NUMBER(10),
  parent_stable_id         varchar2(255),
--parent_ontology_term_id         NUMBER(10) NOT NULL,
  stable_id varchar2(255) NOT NULL,
  non_ontological_name                  varchar(1500),
  data_type                    varchar2(10) not null,
  distinct_values_count            integer,
  is_multi_valued                number(1),
  data_shape                     varchar2(30),
  unit                          varchar2(400),
  unit_ontology_term_id         NUMBER(10),
  precision                     integer,
  ordered_values                CLOB,    
  range_min                     varchar2(16),
  range_max                     varchar2(16),
  bin_width                    varchar2(16),
  mean                          varchar2(16),
  median                        varchar2(16),
  lower_quartile               varchar2(16),
  upper_quartile               varchar2(16),
  FOREIGN KEY (entity_type_id) REFERENCES VDI_DATASETS_&1..EntityType,
  FOREIGN KEY (process_type_id) REFERENCES VDI_DATASETS_&1..ProcessType,
  PRIMARY KEY (attribute_id),
  CONSTRAINT ensure_ov_json CHECK (ordered_values is json)   
);

GRANT INSERT, SELECT, UPDATE, DELETE ON VDI_DATASETS_&1..Attribute TO gus_w;
GRANT SELECT ON VDI_DATASETS_&1..Attribute TO gus_r;

CREATE SEQUENCE VDI_DATASETS_&1..Attribute_sq;
GRANT SELECT ON VDI_DATASETS_&1..Attribute_sq TO gus_w;
GRANT SELECT ON VDI_DATASETS_&1..Attribute_sq TO gus_r;

CREATE INDEX VDI_DATASETS_&1..attribute_ix_1 ON VDI_DATASETS_&1..attribute (entity_type_id, process_type_id, stable_id, attribute_id) TABLESPACE indx;


-----------------------------------------------------------

CREATE TABLE VDI_DATASETS_&1..AttributeGraph (
  attribute_graph_id                  NUMBER(12) NOT NULL,
  study_id            NUMBER(12) NOT NULL, 
  ontology_term_id         NUMBER(10),
  stable_id                varchar2(255) NOT NULL,
  parent_stable_id              varchar2(255) NOT NULL,
  parent_ontology_term_id       NUMBER(10) NOT NULL,
  provider_label                varchar(4000),
  display_name                  varchar(1500) not null,
  display_order                number(3),
  definition                   varchar2(4000),
  display_type                    varchar2(20),
  hidden                   varchar2(64),
  display_range_min            varchar2(16),
  display_range_max            varchar2(16),
  is_merge_key                 number(1),
  impute_zero                  number(1),
  is_repeated                  number(1),
  bin_width_override           varchar2(16),
  is_temporal                  number(1),
  is_featured                  number(1),
  ordinal_values               CLOB,
  scale                         varchar2(30),
  FOREIGN KEY (study_id) REFERENCES VDI_DATASETS_&1..study,
  PRIMARY KEY (attribute_graph_id),
  CONSTRAINT ensure_ordv_json CHECK (ordinal_values is json),
  CONSTRAINT ensure_prolbl_json CHECK (provider_label is json)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON VDI_DATASETS_&1..AttributeGraph TO gus_w;
GRANT SELECT ON VDI_DATASETS_&1..AttributeGraph TO gus_r;

CREATE SEQUENCE VDI_DATASETS_&1..AttributeGraph_sq;
GRANT SELECT ON VDI_DATASETS_&1..AttributeGraph_sq TO gus_w;
GRANT SELECT ON VDI_DATASETS_&1..AttributeGraph_sq TO gus_r;

CREATE INDEX VDI_DATASETS_&1..attributegraph_ix_1 ON VDI_DATASETS_&1..attributegraph (study_id, ontology_term_id, parent_ontology_term_id, attribute_graph_id) TABLESPACE indx;

---------------------------------------------------------------------------

CREATE TABLE VDI_DATASETS_&1..StudyCharacteristic (
  study_characteristic_id      NUMBER(5) NOT NULL,
  study_id                     NUMBER(12) NOT NULL, 
  attribute_id                 NUMBER(12) NOT NULL,
  value_ontology_term_id       NUMBER(10),
  value                        VARCHAR2(300) NOT NULL,
  FOREIGN KEY (study_id) REFERENCES VDI_DATASETS_&1..study,
  PRIMARY KEY (study_characteristic_id)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON VDI_DATASETS_&1..StudyCharacteristic TO gus_w;
GRANT SELECT ON VDI_DATASETS_&1..StudyCharacteristic TO gus_r;

CREATE SEQUENCE VDI_DATASETS_&1..StudyCharacteristic_sq;
GRANT SELECT ON VDI_DATASETS_&1..StudyCharacteristic_sq TO gus_w;
GRANT SELECT ON VDI_DATASETS_&1..StudyCharacteristic_sq TO gus_r;

CREATE INDEX VDI_DATASETS_&1..StudyCharacteristic_ix_1 ON VDI_DATASETS_&1..StudyCharacteristic (study_id, attribute_id, value) TABLESPACE indx;

--------------------------------------------------------------------------------------------------

-- for mega study, we need to prefix the stable id with the study stable id (bfv=big fat view)
create or replace view VDI_DATASETS_&1..entityattributes_bfv as
select ea.entity_attributes_id
     ,  case when ec.entity_type_id = ea.entity_type_id
            then ea.stable_id
            else s2.stable_id || '|' || ea.stable_id
        end as stable_id
     , ea.entity_type_id as orig_entity_type_id
     , ea.atts
--     , ea.row_project_id
     , et.type_id as entity_type_ontology_term_id
     , ec.entity_type_id
     , s.stable_id as study_stable_id
     , s.INTERNAL_ABBREV as study_internal_abbrev
     , s.study_id as study_id
from VDI_DATASETS_&1..entityclassification ec
   , VDI_DATASETS_&1..entityattributes ea
   , VDI_DATASETS_&1..entitytype et
   , VDI_DATASETS_&1..study s
   , VDI_DATASETS_&1..entitytype et2
   , VDI_DATASETS_&1..study s2
 where ec.entity_attributes_id = ea.entity_attributes_id
and ec.entity_type_id = et.entity_type_id
and et.study_id = s.study_id
and ea.ENTITY_TYPE_ID = et2.entity_type_id
and et2.study_id = s2.study_id;

GRANT select ON VDI_DATASETS_&1..entityattributes_bfv TO gus_r;
GRANT select ON VDI_DATASETS_&1..entityattributes_bfv TO gus_w;

----------------------------------------------------------------


CREATE TABLE VDI_DATASETS_&1..AnnotationProperties (
  annotation_properties_id   NUMBER(10) NOT NULL,
  ontology_term_id       NUMBER(10) NOT NULL,
  study_id            NUMBER(12) NOT NULL,
  props                         CLOB,
  external_database_release_id number(10) NOT NULL,
  FOREIGN KEY (study_id) REFERENCES VDI_DATASETS_&1..study (study_id),
  PRIMARY KEY (annotation_properties_id),
  CONSTRAINT ensure_anp_json CHECK (props is json)
);

CREATE SEQUENCE VDI_DATASETS_&1..AnnotationProperties_sq;

GRANT insert, select, update, delete ON VDI_DATASETS_&1..AnnotationProperties TO gus_w;
GRANT select ON VDI_DATASETS_&1..AnnotationProperties TO gus_r;
GRANT select ON VDI_DATASETS_&1..AnnotationProperties_sq TO gus_w;



exit;
