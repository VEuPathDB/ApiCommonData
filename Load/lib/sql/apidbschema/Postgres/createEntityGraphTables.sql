-- set CONCAT OFF;

-- so the foreign key constraints are allowed
-- grant references on &2.OntologyTerm to &1;
-- grant references on &2.ExternalDatabaseRelease to &1;

CREATE TABLE :VAR1.Study (
 study_id            NUMERIC(12) NOT NULL,
 stable_id                         VARCHAR(200) NOT NULL,
 external_database_release_id numeric(10) NOT NULL,
 internal_abbrev              varchar(75),
 max_attr_length              numeric(4),
 modification_date            TIMESTAMP NOT NULL,
 user_read                    NUMERIC(1) NOT NULL,
 user_write                   NUMERIC(1) NOT NULL,
 group_read                   NUMERIC(1) NOT NULL,
 group_write                  NUMERIC(1) NOT NULL,
 other_read                   NUMERIC(1) NOT NULL,
 other_write                  NUMERIC(1) NOT NULL,
 row_user_id                  NUMERIC(12) NOT NULL,
 row_group_id                 NUMERIC(3) NOT NULL,
 row_project_id               NUMERIC(4) NOT NULL,
 row_alg_invocation_id        NUMERIC(12) NOT NULL,
 FOREIGN KEY (external_database_release_id) REFERENCES :VAR2.ExternalDatabaseRelease,
 PRIMARY KEY (study_id),
 CONSTRAINT unique_stable_id UNIQUE (stable_id)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON :VAR1.Study TO gus_w;
GRANT SELECT ON :VAR1.Study TO gus_r;

CREATE SEQUENCE :VAR1.Study_sq;
GRANT SELECT ON :VAR1.Study_sq TO gus_w;
GRANT SELECT ON :VAR1.Study_sq TO gus_r;

CREATE INDEX study_ix_1 ON :VAR1.study (external_database_release_id, stable_id, internal_abbrev, study_id) TABLESPACE indx;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'Study',
       'Standard', 'study_id',
       d.database_id, 0, 0, NULL, NULL, 1,localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = lower(':VAR1')) d
WHERE 'study' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

-----------------------------------------------------------

CREATE TABLE :VAR1.EntityType (
 entity_type_id            NUMERIC(12) NOT NULL,
 name                      VARCHAR(200) NOT NULL,
 type_id                   NUMERIC(10),
 isa_type                     VARCHAR(50),
 study_id            NUMERIC(12) NOT NULL,
 internal_abbrev              VARCHAR(50) NOT NULL,
 cardinality                  NUMERIC(38,0),
 modification_date            TIMESTAMP NOT NULL,
 user_read                    NUMERIC(1) NOT NULL,
 user_write                   NUMERIC(1) NOT NULL,
 group_read                   NUMERIC(1) NOT NULL,
 group_write                  NUMERIC(1) NOT NULL,
 other_read                   NUMERIC(1) NOT NULL,
 other_write                  NUMERIC(1) NOT NULL,
 row_user_id                  NUMERIC(12) NOT NULL,
 row_group_id                 NUMERIC(3) NOT NULL,
 row_project_id               NUMERIC(4) NOT NULL,
 row_alg_invocation_id        NUMERIC(12) NOT NULL,
 FOREIGN KEY (study_id) REFERENCES :VAR1.study,
 FOREIGN KEY (type_id) REFERENCES :VAR2.ontologyterm,
 PRIMARY KEY (entity_type_id)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON :VAR1.EntityType TO gus_w;
GRANT SELECT ON :VAR1.EntityType TO gus_r;

CREATE SEQUENCE :VAR1.EntityType_sq;
GRANT SELECT ON :VAR1.EntityType_sq TO gus_w;
GRANT SELECT ON :VAR1.EntityType_sq TO gus_r;

CREATE UNIQUE INDEX :VAR1.entitytype_ix_1 ON :VAR1.entitytype (study_id, entity_type_id) TABLESPACE indx;
CREATE UNIQUE INDEX :VAR1.entitytype_ix_2 ON :VAR1.entitytype (type_id, entity_type_id) TABLESPACE indx;
CREATE UNIQUE INDEX :VAR1.entitytype_ix_3 ON :VAR1.entitytype (study_id, internal_abbrev) TABLESPACE indx;


INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'EntityType',
       'Standard', 'entity_type_id',
       d.database_id, 0, 0, NULL, NULL, 1,localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM 
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = lower(':VAR1')) d
WHERE 'entitytype' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

-----------------------------------------------------------

CREATE TABLE :VAR1.ProcessType (
 process_type_id            NUMERIC(12) NOT NULL,
 name                         VARCHAR(200) NOT NULL,
 description                  VARCHAR(4000),
 type_id                      NUMERIC(10),
 modification_date            TIMESTAMP NOT NULL,
 user_read                    NUMERIC(1) NOT NULL,
 user_write                   NUMERIC(1) NOT NULL,
 group_read                   NUMERIC(1) NOT NULL,
 group_write                  NUMERIC(1) NOT NULL,
 other_read                   NUMERIC(1) NOT NULL,
 other_write                  NUMERIC(1) NOT NULL,
 row_user_id                  NUMERIC(12) NOT NULL,
 row_group_id                 NUMERIC(3) NOT NULL,
 row_project_id               NUMERIC(4) NOT NULL,
 row_alg_invocation_id        NUMERIC(12) NOT NULL,
FOREIGN KEY (type_id) REFERENCES :VAR2.ontologyterm,
 PRIMARY KEY (process_type_id)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON :VAR1.ProcessType TO gus_w;
GRANT SELECT ON :VAR1.ProcessType TO gus_r;

CREATE SEQUENCE :VAR1.ProcessType_sq;
GRANT SELECT ON :VAR1.ProcessType_sq TO gus_w;
GRANT SELECT ON :VAR1.ProcessType_sq TO gus_r;

CREATE INDEX processtype_ix_1 ON :VAR1.processtype (type_id, process_type_id) TABLESPACE indx;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'ProcessType',
       'Standard', 'process_type_id',
       d.database_id, 0, 0, NULL, NULL, 1,localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM 
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = lower(':VAR1')) d
WHERE 'processtype' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

-----------------------------------------------------------

CREATE TABLE :VAR1.EntityAttributes (
 entity_attributes_id         NUMERIC(12) NOT NULL,
 stable_id                         VARCHAR(200) NOT NULL,
 entity_type_id               NUMERIC(12) NOT NULL,
 atts                         CLOB,
 modification_date            TIMESTAMP NOT NULL,
 user_read                    NUMERIC(1) NOT NULL,
 user_write                   NUMERIC(1) NOT NULL,
 group_read                   NUMERIC(1) NOT NULL,
 group_write                  NUMERIC(1) NOT NULL,
 other_read                   NUMERIC(1) NOT NULL,
 other_write                  NUMERIC(1) NOT NULL,
 row_user_id                  NUMERIC(12) NOT NULL,
 row_group_id                 NUMERIC(3) NOT NULL,
 row_project_id               NUMERIC(4) NOT NULL,
 row_alg_invocation_id        NUMERIC(12) NOT NULL,
 PRIMARY KEY (entity_attributes_id),
FOREIGN KEY (entity_type_id) REFERENCES :VAR1.EntityType --,
--CONSTRAINT ensure_va_json CHECK (atts is json)
);

-- 
--CREATE SEARCH INDEX :VAR1.va_search_ix ON :VAR1.entityattributes (atts) FOR JSON;

CREATE INDEX entityattributes_ix_1 ON :VAR1.entityattributes (entity_type_id, entity_attributes_id) TABLESPACE indx;

GRANT INSERT, SELECT, UPDATE, DELETE ON :VAR1.EntityAttributes TO gus_w;
GRANT SELECT ON :VAR1.EntityAttributes TO gus_r;

CREATE SEQUENCE :VAR1.EntityAttributes_sq;
GRANT SELECT ON :VAR1.EntityAttributes_sq TO gus_w;
GRANT SELECT ON :VAR1.EntityAttributes_sq TO gus_r;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'EntityAttributes',
       'Standard', 'entity_attributes_id',
       d.database_id, 0, 0, NULL, NULL, 1,localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM 
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = lower(':VAR1')) d
WHERE 'entityattributes' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

-----------------------------------------------------------

CREATE TABLE :VAR1.EntityClassification (
 entity_classification_id         NUMERIC(12) NOT NULL,
 entity_attributes_id         NUMERIC(12) NOT NULL,
 entity_type_id               NUMERIC(12) NOT NULL,
 modification_date            TIMESTAMP NOT NULL,
 user_read                    NUMERIC(1) NOT NULL,
 user_write                   NUMERIC(1) NOT NULL,
 group_read                   NUMERIC(1) NOT NULL,
 group_write                  NUMERIC(1) NOT NULL,
 other_read                   NUMERIC(1) NOT NULL,
 other_write                  NUMERIC(1) NOT NULL,
 row_user_id                  NUMERIC(12) NOT NULL,
 row_group_id                 NUMERIC(3) NOT NULL,
 row_project_id               NUMERIC(4) NOT NULL,
 row_alg_invocation_id        NUMERIC(12) NOT NULL,
 FOREIGN KEY (entity_type_id) REFERENCES :VAR1.EntityType,
 FOREIGN KEY (entity_attributes_id) REFERENCES :VAR1.EntityAttributes,
 PRIMARY KEY (entity_classification_id)
);

CREATE INDEX entityclassification_ix_1 ON :VAR1.entityclassification (entity_type_id, entity_attributes_id) TABLESPACE indx;
CREATE INDEX entityclassification_ix_2 ON :VAR1.entityclassification (entity_attributes_id, entity_type_id) TABLESPACE indx;

GRANT INSERT, SELECT, UPDATE, DELETE ON :VAR1.EntityClassification TO gus_w;
GRANT SELECT ON :VAR1.EntityClassification TO gus_r;

CREATE SEQUENCE :VAR1.EntityClassification_sq;
GRANT SELECT ON :VAR1.EntityClassification_sq TO gus_w;
GRANT SELECT ON :VAR1.EntityClassification_sq TO gus_r;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'EntityClassification',
       'Standard', 'entity_classification_id',
       d.database_id, 0, 0, NULL, NULL, 1,localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM 
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = lower(':VAR1')) d
WHERE 'entityclassification' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

-----------------------------------------------------------

CREATE TABLE :VAR1.ProcessAttributes (
 process_attributes_id           NUMERIC(12) NOT NULL,
 process_type_id                NUMERIC(12) NOT NULL,
 in_entity_id                 NUMERIC(12) NOT NULL,
 out_entity_id                NUMERIC(12) NOT NULL,
 atts                         CLOB,
 modification_date            TIMESTAMP NOT NULL,
 user_read                    NUMERIC(1) NOT NULL,
 user_write                   NUMERIC(1) NOT NULL,
 group_read                   NUMERIC(1) NOT NULL,
 group_write                  NUMERIC(1) NOT NULL,
 other_read                   NUMERIC(1) NOT NULL,
 other_write                  NUMERIC(1) NOT NULL,
 row_user_id                  NUMERIC(12) NOT NULL,
 row_group_id                 NUMERIC(3) NOT NULL,
 row_project_id               NUMERIC(4) NOT NULL,
 row_alg_invocation_id        NUMERIC(12) NOT NULL,
 FOREIGN KEY (in_entity_id) REFERENCES :VAR1.entityattributes,
 FOREIGN KEY (out_entity_id) REFERENCES :VAR1.entityattributes,
 FOREIGN KEY (process_type_id) REFERENCES :VAR1.processtype,
 PRIMARY KEY (process_attributes_id) -- ,
--  CONSTRAINT ensure_ea_json CHECK (atts is json)   
);

CREATE INDEX ea_in_ix ON :VAR1.processattributes (in_entity_id, out_entity_id, process_attributes_id) tablespace indx;
CREATE INDEX ea_out_ix ON :VAR1.processattributes (out_entity_id, in_entity_id, process_attributes_id) tablespace indx;

CREATE INDEX ea_ix_1 ON :VAR1.processattributes (process_type_id, process_attributes_id) TABLESPACE indx;

GRANT INSERT, SELECT, UPDATE, DELETE ON :VAR1.ProcessAttributes TO gus_w;
GRANT SELECT ON :VAR1.ProcessAttributes TO gus_r;

CREATE SEQUENCE :VAR1.ProcessAttributes_sq;
GRANT SELECT ON :VAR1.ProcessAttributes_sq TO gus_w;
GRANT SELECT ON :VAR1.ProcessAttributes_sq TO gus_r;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'ProcessAttributes',
       'Standard', 'process_attributes_id',
       d.database_id, 0, 0, NULL, NULL, 1,localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM 
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = lower(':VAR1')) d
WHERE 'processattributes' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

-----------------------------------------------------------

CREATE TABLE :VAR1.EntityTypeGraph (
 entity_type_graph_id           NUMERIC(12) NOT NULL,
 study_id                       NUMERIC(12) NOT NULL,
 study_stable_id                varchar(200),
 parent_stable_id             varchar(255),
 parent_id                    NUMERIC(12),
 stable_id                    varchar(255),
 entity_type_id                NUMERIC(12) NOT NULL,
 display_name                 VARCHAR(200) NOT NULL,
 display_name_plural          VARCHAR(200),
 description                  VARCHAR(4000),
 internal_abbrev              VARCHAR(50) NOT NULL,
 has_attribute_collections    NUMERIC(1),
 is_many_to_one_with_parent   NUMERIC(1),
 cardinality                  NUMERIC(38,0),
 modification_date            TIMESTAMP NOT NULL,
 user_read                    NUMERIC(1) NOT NULL,
 user_write                   NUMERIC(1) NOT NULL,
 group_read                   NUMERIC(1) NOT NULL,
 group_write                  NUMERIC(1) NOT NULL,
 other_read                   NUMERIC(1) NOT NULL,
 other_write                  NUMERIC(1) NOT NULL,
 row_user_id                  NUMERIC(12) NOT NULL,
 row_group_id                 NUMERIC(3) NOT NULL,
 row_project_id               NUMERIC(4) NOT NULL,
 row_alg_invocation_id        NUMERIC(12) NOT NULL,
 FOREIGN KEY (study_id) REFERENCES :VAR1.study,
 FOREIGN KEY (parent_id) REFERENCES :VAR1.entitytype,
 FOREIGN KEY (entity_type_id) REFERENCES :VAR1.entitytype,
 PRIMARY KEY (entity_type_graph_id)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON :VAR1.EntityTypeGraph TO gus_w;
GRANT SELECT ON :VAR1.EntityTypeGraph TO gus_r;

CREATE SEQUENCE :VAR1.EntityTypeGraph_sq;
GRANT SELECT ON :VAR1.EntityTypeGraph_sq TO gus_w;
GRANT SELECT ON :VAR1.EntityTypeGraph_sq TO gus_r;

CREATE INDEX entitytypegraph_ix_1 ON :VAR1.entitytypegraph (study_id, entity_type_id, parent_id, entity_type_graph_id) TABLESPACE indx;
CREATE INDEX entitytypegraph_ix_2 ON :VAR1.entitytypegraph (parent_id, entity_type_graph_id) TABLESPACE indx;
CREATE INDEX entitytypegraph_ix_3 ON :VAR1.entitytypegraph (entity_type_id, entity_type_graph_id) TABLESPACE indx;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'EntityTypeGraph',
       'Standard', 'entity_type_graph_id',
       d.database_id, 0, 0, NULL, NULL, 1,localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM 
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = lower(':VAR1')) d
WHERE 'entitytypegraph' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);


-----------------------------------------------------------

CREATE TABLE :VAR1.AttributeUnit (
 attribute_unit_id                NUMERIC(12) NOT NULL,
 entity_type_id                      NUMERIC(12) NOT NULL,
 attr_ontology_term_id               NUMERIC(10) NOT NULL,
 unit_ontology_term_id               NUMERIC(10) NOT NULL,
 modification_date            TIMESTAMP NOT NULL,
 user_read                    NUMERIC(1) NOT NULL,
 user_write                   NUMERIC(1) NOT NULL,
 group_read                   NUMERIC(1) NOT NULL,
 group_write                  NUMERIC(1) NOT NULL,
 other_read                   NUMERIC(1) NOT NULL,
 other_write                  NUMERIC(1) NOT NULL,
 row_user_id                  NUMERIC(12) NOT NULL,
 row_group_id                 NUMERIC(3) NOT NULL,
 row_project_id               NUMERIC(4) NOT NULL,
 row_alg_invocation_id        NUMERIC(12) NOT NULL,
 FOREIGN KEY (entity_type_id) REFERENCES :VAR1.EntityType,
FOREIGN KEY (attr_ontology_term_id) REFERENCES :VAR2.ontologyterm,
FOREIGN KEY (unit_ontology_term_id) REFERENCES :VAR2.ontologyterm,
 PRIMARY KEY (attribute_unit_id)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON :VAR1.AttributeUnit TO gus_w;
GRANT SELECT ON :VAR1.AttributeUnit TO gus_r;

CREATE SEQUENCE :VAR1.AttributeUnit_sq;
GRANT SELECT ON :VAR1.AttributeUnit_sq TO gus_w;
GRANT SELECT ON :VAR1.AttributeUnit_sq TO gus_r;

CREATE INDEX attributeunit_ix_1 ON :VAR1.attributeunit (entity_type_id, attr_ontology_term_id, unit_ontology_term_id, attribute_unit_id) TABLESPACE indx;
CREATE INDEX attributeunit_ix_2 ON :VAR1.attributeunit (attr_ontology_term_id, attribute_unit_id) TABLESPACE indx;
CREATE INDEX attributeunit_ix_3 ON :VAR1.attributeunit (unit_ontology_term_id, attribute_unit_id) TABLESPACE indx;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'AttributeUnit',
       'Standard', 'attribute_unit_id',
       d.database_id, 0, 0, NULL, NULL, 1,localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM 
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = lower(':VAR1')) d
WHERE 'attributeunit' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

-----------------------------------------------------------


CREATE TABLE :VAR1.ProcessTypeComponent (
 process_type_component_id       NUMERIC(12) NOT NULL,
 process_type_id                 NUMERIC(12) NOT NULL,
 component_id                 NUMERIC(12) NOT NULL,
 order_num                    NUMERIC(2) NOT NULL,
 modification_date            TIMESTAMP NOT NULL,
 user_read                    NUMERIC(1) NOT NULL,
 user_write                   NUMERIC(1) NOT NULL,
 group_read                   NUMERIC(1) NOT NULL,
 group_write                  NUMERIC(1) NOT NULL,
 other_read                   NUMERIC(1) NOT NULL,
 other_write                  NUMERIC(1) NOT NULL,
 row_user_id                  NUMERIC(12) NOT NULL,
 row_group_id                 NUMERIC(3) NOT NULL,
 row_project_id               NUMERIC(4) NOT NULL,
 row_alg_invocation_id        NUMERIC(12) NOT NULL,
 FOREIGN KEY (process_type_id) REFERENCES :VAR1.ProcessType,
 FOREIGN KEY (component_id) REFERENCES :VAR1.ProcessType,
 PRIMARY KEY (process_type_component_id)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON :VAR1.ProcessTypeComponent TO gus_w;
GRANT SELECT ON :VAR1.ProcessTypeComponent TO gus_r;

CREATE SEQUENCE :VAR1.ProcessTypeComponent_sq;
GRANT SELECT ON :VAR1.ProcessTypeComponent_sq TO gus_w;
GRANT SELECT ON :VAR1.ProcessTypeComponent_sq TO gus_r;

CREATE INDEX ptc_ix_1 ON :VAR1.processtypecomponent (process_type_id, component_id, order_num, process_type_component_id) TABLESPACE indx;
CREATE INDEX ptc_ix_2 ON :VAR1.processtypecomponent (component_id, process_type_component_id) TABLESPACE indx;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'ProcessTypeComponent',
       'Standard', 'process_type_component_id',
       d.database_id, 0, 0, NULL, NULL, 1,localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM 
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = lower(':VAR1')) d
WHERE 'processtypecomponent' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);


-----------------------------------------------------------


CREATE TABLE :VAR1.Attribute (
  attribute_id                  NUMERIC(12) NOT NULL,
  entity_type_id                NUMERIC(12) not null,
  entity_type_stable_id         varchar(255),
  process_type_id                 NUMERIC(12),
  ontology_term_id         NUMERIC(10),
  parent_stable_id         varchar(255),
--parent_ontology_term_id         NUMERIC(10) NOT NULL,
  stable_id varchar(255) NOT NULL,
  non_ontological_name                  varchar(1500),
  data_type                    varchar(10) not null,
  distinct_values_count            integer,
  is_multi_valued                numeric(1),
  data_shape                     varchar(30),
  unit                          varchar(400),
  unit_ontology_term_id         NUMERIC(10),
  precision                     integer,
  ordered_values                CLOB,    
  range_min                     varchar(16),
  range_max                     varchar(16),
  bin_width                    varchar(16),
  mean                          varchar(16),
  median                        varchar(16),
  lower_quartile               varchar(16),
  upper_quartile               varchar(16),
  modification_date            TIMESTAMP NOT NULL,
  user_read                    NUMERIC(1) NOT NULL,
  user_write                   NUMERIC(1) NOT NULL,
  group_read                   NUMERIC(1) NOT NULL,
  group_write                  NUMERIC(1) NOT NULL,
  other_read                   NUMERIC(1) NOT NULL,
  other_write                  NUMERIC(1) NOT NULL,
  row_user_id                  NUMERIC(12) NOT NULL,
  row_group_id                 NUMERIC(3) NOT NULL,
  row_project_id               NUMERIC(4) NOT NULL,
  row_alg_invocation_id        NUMERIC(12) NOT NULL,
  FOREIGN KEY (entity_type_id) REFERENCES :VAR1.EntityType,
  FOREIGN KEY (process_type_id) REFERENCES :VAR1.ProcessType,
 FOREIGN KEY (ontology_term_id) REFERENCES :VAR2.ontologyterm,
 FOREIGN KEY (unit_ontology_term_id) REFERENCES :VAR2.ontologyterm,
  PRIMARY KEY (attribute_id) -- ,
--  CONSTRAINT ensure_ov_json CHECK (ordered_values is json)   
);

GRANT INSERT, SELECT, UPDATE, DELETE ON :VAR1.Attribute TO gus_w;
GRANT SELECT ON :VAR1.Attribute TO gus_r;

CREATE SEQUENCE :VAR1.Attribute_sq;
GRANT SELECT ON :VAR1.Attribute_sq TO gus_w;
GRANT SELECT ON :VAR1.Attribute_sq TO gus_r;

CREATE INDEX attribute_ix_1 ON :VAR1.attribute (entity_type_id, process_type_id, stable_id, attribute_id) TABLESPACE indx;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'Attribute',
       'Standard', 'attribute_id',
       d.database_id, 0, 0, NULL, NULL, 1,localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM 
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = lower(':VAR1')) d
WHERE 'attribute' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);



-----------------------------------------------------------

CREATE TABLE :VAR1.AttributeGraph (
  attribute_graph_id                  NUMERIC(12) NOT NULL,
  study_id            NUMERIC(12) NOT NULL, 
  ontology_term_id         NUMERIC(10),
  stable_id                varchar(255) NOT NULL,
  parent_stable_id              varchar(255) NOT NULL,
  parent_ontology_term_id       NUMERIC(10) NOT NULL,
  provider_label                varchar(4000),
  display_name                  varchar(1500) not null,
  display_order                numeric(3),
  definition                   varchar(4000),
  display_type                    varchar(20),
  hidden                   varchar(64),
  display_range_min            varchar(16),
  display_range_max            varchar(16),
  is_merge_key                 numeric(1),
  variable_spec_to_impute_zeroes_for     varchar(200),
  has_study_dependent_vocabulary         varchar(20),
  weighting_variable_spec                varchar(200),
  impute_zero                  numeric(1),
  is_repeated                  numeric(1),
  bin_width_override           varchar(16),
  is_temporal                  numeric(1),
  is_featured                  numeric(1),
  ordinal_values               CLOB,
  scale                         varchar(30),
  modification_date            TIMESTAMP NOT NULL,
  user_read                    NUMERIC(1) NOT NULL,
  user_write                   NUMERIC(1) NOT NULL,
  group_read                   NUMERIC(1) NOT NULL,
  group_write                  NUMERIC(1) NOT NULL,
  other_read                   NUMERIC(1) NOT NULL,
  other_write                  NUMERIC(1) NOT NULL,
  row_user_id                  NUMERIC(12) NOT NULL,
  row_group_id                 NUMERIC(3) NOT NULL,
  row_project_id               NUMERIC(4) NOT NULL,
  row_alg_invocation_id        NUMERIC(12) NOT NULL,
 FOREIGN KEY (ontology_term_id) REFERENCES :VAR2.ontologyterm,
 FOREIGN KEY (parent_ontology_term_id) REFERENCES :VAR2.ontologyterm,
  FOREIGN KEY (study_id) REFERENCES :VAR1.study,
  PRIMARY KEY (attribute_graph_id) -- ,
--  CONSTRAINT ensure_ordv_json CHECK (ordinal_values is json),
--  CONSTRAINT ensure_prolbl_json CHECK (provider_label is json)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON :VAR1.AttributeGraph TO gus_w;
GRANT SELECT ON :VAR1.AttributeGraph TO gus_r;

CREATE SEQUENCE :VAR1.AttributeGraph_sq;
GRANT SELECT ON :VAR1.AttributeGraph_sq TO gus_w;
GRANT SELECT ON :VAR1.AttributeGraph_sq TO gus_r;

CREATE INDEX attributegraph_ix_1 ON :VAR1.attributegraph (study_id, ontology_term_id, parent_ontology_term_id, attribute_graph_id) TABLESPACE indx;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'AttributeGraph',
       'Standard', 'attribute_graph_id',
       d.database_id, 0, 0, NULL, NULL, 1,localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM 
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = lower(':VAR1')) d
WHERE 'attributegraph' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);


CREATE TABLE :VAR1.StudyCharacteristic (
  study_characteristic_id      NUMERIC(5) NOT NULL,
  study_id                     NUMERIC(12) NOT NULL, 
  attribute_id                 NUMERIC(12) NOT NULL,
  value_ontology_term_id       NUMERIC(10),
  value                        VARCHAR(300) NOT NULL,
  modification_date            TIMESTAMP NOT NULL,
  user_read                    NUMERIC(1) NOT NULL,
  user_write                   NUMERIC(1) NOT NULL,
  group_read                   NUMERIC(1) NOT NULL,
  group_write                  NUMERIC(1) NOT NULL,
  other_read                   NUMERIC(1) NOT NULL,
  other_write                  NUMERIC(1) NOT NULL,
  row_user_id                  NUMERIC(12) NOT NULL,
  row_group_id                 NUMERIC(3) NOT NULL,
  row_project_id               NUMERIC(4) NOT NULL,
  row_alg_invocation_id        NUMERIC(12) NOT NULL,
 FOREIGN KEY (value_ontology_term_id) REFERENCES :VAR2.ontologyterm,
 FOREIGN KEY (attribute_id) REFERENCES :VAR2.ontologyterm,
  FOREIGN KEY (study_id) REFERENCES :VAR1.study,
  PRIMARY KEY (study_characteristic_id)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON :VAR1.StudyCharacteristic TO gus_w;
GRANT SELECT ON :VAR1.StudyCharacteristic TO gus_r;

CREATE SEQUENCE :VAR1.StudyCharacteristic_sq;
GRANT SELECT ON :VAR1.StudyCharacteristic_sq TO gus_w;
GRANT SELECT ON :VAR1.StudyCharacteristic_sq TO gus_r;

CREATE INDEX StudyCharacteristic_ix_1 ON :VAR1.StudyCharacteristic (study_id, attribute_id, value) TABLESPACE indx;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'StudyCharacteristic',
       'Standard', 'study_characteristic_id',
       d.database_id, 0, 0, NULL, NULL, 1,localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM 
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = lower(':VAR1')) d
WHERE 'study_characteristic_id' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);


-- for mega study, we need to prefix the stable id with the study stable id (bfv=big fat view)
create or replace view :VAR1.entityattributes_bfv as
select ea.entity_attributes_id
     ,  case when ec.entity_type_id = ea.entity_type_id
            then ea.stable_id
            else s2.stable_id || '|' || ea.stable_id
        end as stable_id
     , ea.entity_type_id as orig_entity_type_id
     , ea.atts
     , ea.row_project_id
     , et.type_id as entity_type_ontology_term_id
     , ec.entity_type_id
     , s.stable_id as study_stable_id
     , s.INTERNAL_ABBREV as study_internal_abbrev
     , s.study_id as study_id
from :VAR1.entityclassification ec
   , :VAR1.entityattributes ea
   , :VAR1.entitytype et
   , :VAR1.study s
   , :VAR1.entitytype et2
   , :VAR1.study s2
 where ec.entity_attributes_id = ea.entity_attributes_id
and ec.entity_type_id = et.entity_type_id
and et.study_id = s.study_id
and ea.ENTITY_TYPE_ID = et2.entity_type_id
and et2.study_id = s2.study_id;

GRANT select ON :VAR1.entityattributes_bfv TO gus_r;
GRANT select ON :VAR1.entityattributes_bfv TO gus_w;

CREATE TABLE :VAR1.AnnotationProperties (
  annotation_properties_id   NUMERIC(10) NOT NULL,
  ontology_term_id       NUMERIC(10) NOT NULL,
  study_id            NUMERIC(12) NOT NULL,
  props                         CLOB,
 external_database_release_id numeric(10) NOT NULL,
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
  FOREIGN KEY (ontology_term_id) REFERENCES :VAR2.OntologyTerm (ontology_term_id),
  FOREIGN KEY (study_id) REFERENCES :VAR1.study (study_id),
 FOREIGN KEY (external_database_release_id) REFERENCES :VAR2.ExternalDatabaseRelease,
PRIMARY KEY (annotation_properties_id) --,
--  CONSTRAINT ensure_anp_json CHECK (props is json)
);

CREATE SEQUENCE :VAR1.AnnotationProperties_sq;

GRANT insert, select, update, delete ON :VAR1.AnnotationProperties TO gus_w;
GRANT select ON :VAR1.AnnotationProperties TO gus_r;
GRANT select ON :VAR1.AnnotationProperties_sq TO gus_w;


INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable,
     modification_date, user_read, user_write, group_read, group_write,
     other_read, other_write, row_user_id, row_group_id, row_project_id,
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'AnnotationProperties',
       'Standard', 'annotation_properties_id',
       d.database_id, 0, 0, NULL, NULL, 1,localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM 
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = lower(':VAR1')) d
WHERE 'annotationproperties' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

exit;
