-- so the foreign key constraints are allowed
grant references on &2..OntologyTerm to &1;
grant references on &2..ExternalDatabaseRelease to &1;

CREATE TABLE &1..Study (
 study_id            NUMBER(12) NOT NULL,
 stable_id                         VARCHAR2(200) NOT NULL,
 external_database_release_id number(10) NOT NULL,
 internal_abbrev              varchar2(75),
 max_attr_length              number(4),
 modification_date            DATE NOT NULL,
 user_read                    NUMBER(1) NOT NULL,
 user_write                   NUMBER(1) NOT NULL,
 group_read                   NUMBER(1) NOT NULL,
 group_write                  NUMBER(1) NOT NULL,
 other_read                   NUMBER(1) NOT NULL,
 other_write                  NUMBER(1) NOT NULL,
 row_user_id                  NUMBER(12) NOT NULL,
 row_group_id                 NUMBER(3) NOT NULL,
 row_project_id               NUMBER(4) NOT NULL,
 row_alg_invocation_id        NUMBER(12) NOT NULL,
 FOREIGN KEY (external_database_release_id) REFERENCES &2..ExternalDatabaseRelease,
 PRIMARY KEY (study_id),
 CONSTRAINT unique_stable_id UNIQUE (stable_id)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON &1..Study TO gus_w;
GRANT SELECT ON &1..Study TO gus_r;

CREATE SEQUENCE &1..Study_sq;
GRANT SELECT ON &1..Study_sq TO gus_w;
GRANT SELECT ON &1..Study_sq TO gus_r;

CREATE INDEX &1..study_ix_1 ON &1..study (external_database_release_id, stable_id, internal_abbrev, study_id) TABLESPACE indx;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'Study',
       'Standard', 'study_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = lower('&1')) d
WHERE 'study' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

-----------------------------------------------------------

CREATE TABLE &1..EntityType (
 entity_type_id            NUMBER(12) NOT NULL,
 name                      VARCHAR2(200) NOT NULL,
 type_id                   NUMBER(10),
 isa_type                     VARCHAR2(50),
 study_id            NUMBER(12) NOT NULL,
 internal_abbrev              VARCHAR2(50) NOT NULL,
 cardinality                  NUMBER(38,0),
 modification_date            DATE NOT NULL,
 user_read                    NUMBER(1) NOT NULL,
 user_write                   NUMBER(1) NOT NULL,
 group_read                   NUMBER(1) NOT NULL,
 group_write                  NUMBER(1) NOT NULL,
 other_read                   NUMBER(1) NOT NULL,
 other_write                  NUMBER(1) NOT NULL,
 row_user_id                  NUMBER(12) NOT NULL,
 row_group_id                 NUMBER(3) NOT NULL,
 row_project_id               NUMBER(4) NOT NULL,
 row_alg_invocation_id        NUMBER(12) NOT NULL,
 FOREIGN KEY (study_id) REFERENCES &1..study,
 FOREIGN KEY (type_id) REFERENCES &2..ontologyterm,
 PRIMARY KEY (entity_type_id)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON &1..EntityType TO gus_w;
GRANT SELECT ON &1..EntityType TO gus_r;

CREATE SEQUENCE &1..EntityType_sq;
GRANT SELECT ON &1..EntityType_sq TO gus_w;
GRANT SELECT ON &1..EntityType_sq TO gus_r;

CREATE UNIQUE INDEX &1..entitytype_ix_1 ON &1..entitytype (study_id, entity_type_id) TABLESPACE indx;
CREATE UNIQUE INDEX &1..entitytype_ix_2 ON &1..entitytype (type_id, entity_type_id) TABLESPACE indx;
CREATE UNIQUE INDEX &1..entitytype_ix_3 ON &1..entitytype (study_id, internal_abbrev) TABLESPACE indx;


INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'EntityType',
       'Standard', 'entity_type_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = lower('&1')) d
WHERE 'entitytype' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

-----------------------------------------------------------

CREATE TABLE &1..ProcessType (
 process_type_id            NUMBER(12) NOT NULL,
 name                         VARCHAR2(200) NOT NULL,
 description                  VARCHAR2(4000),
 type_id                      NUMBER(10),
 modification_date            DATE NOT NULL,
 user_read                    NUMBER(1) NOT NULL,
 user_write                   NUMBER(1) NOT NULL,
 group_read                   NUMBER(1) NOT NULL,
 group_write                  NUMBER(1) NOT NULL,
 other_read                   NUMBER(1) NOT NULL,
 other_write                  NUMBER(1) NOT NULL,
 row_user_id                  NUMBER(12) NOT NULL,
 row_group_id                 NUMBER(3) NOT NULL,
 row_project_id               NUMBER(4) NOT NULL,
 row_alg_invocation_id        NUMBER(12) NOT NULL,
FOREIGN KEY (type_id) REFERENCES &2..ontologyterm,
 PRIMARY KEY (process_type_id)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON &1..ProcessType TO gus_w;
GRANT SELECT ON &1..ProcessType TO gus_r;

CREATE SEQUENCE &1..ProcessType_sq;
GRANT SELECT ON &1..ProcessType_sq TO gus_w;
GRANT SELECT ON &1..ProcessType_sq TO gus_r;

CREATE INDEX &1..processtype_ix_1 ON &1..processtype (type_id, process_type_id) TABLESPACE indx;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'ProcessType',
       'Standard', 'process_type_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = lower('&1')) d
WHERE 'processtype' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

-----------------------------------------------------------

CREATE TABLE &1..EntityAttributes (
 entity_attributes_id         NUMBER(12) NOT NULL,
 stable_id                         VARCHAR2(200) NOT NULL,
 entity_type_id               NUMBER(12) NOT NULL,
 atts                         CLOB,
 modification_date            DATE NOT NULL,
 user_read                    NUMBER(1) NOT NULL,
 user_write                   NUMBER(1) NOT NULL,
 group_read                   NUMBER(1) NOT NULL,
 group_write                  NUMBER(1) NOT NULL,
 other_read                   NUMBER(1) NOT NULL,
 other_write                  NUMBER(1) NOT NULL,
 row_user_id                  NUMBER(12) NOT NULL,
 row_group_id                 NUMBER(3) NOT NULL,
 row_project_id               NUMBER(4) NOT NULL,
 row_alg_invocation_id        NUMBER(12) NOT NULL,
 PRIMARY KEY (entity_attributes_id),
FOREIGN KEY (entity_type_id) REFERENCES &1..EntityType,
CONSTRAINT ensure_va_json CHECK (atts is json)
);

-- 
--CREATE SEARCH INDEX &1..va_search_ix ON &1..entityattributes (atts) FOR JSON;

CREATE INDEX &1..entityattributes_ix_1 ON &1..entityattributes (entity_type_id, entity_attributes_id) TABLESPACE indx;

GRANT INSERT, SELECT, UPDATE, DELETE ON &1..EntityAttributes TO gus_w;
GRANT SELECT ON &1..EntityAttributes TO gus_r;

CREATE SEQUENCE &1..EntityAttributes_sq;
GRANT SELECT ON &1..EntityAttributes_sq TO gus_w;
GRANT SELECT ON &1..EntityAttributes_sq TO gus_r;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'EntityAttributes',
       'Standard', 'entity_attributes_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = lower('&1')) d
WHERE 'entityattributes' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

-----------------------------------------------------------

CREATE TABLE &1..EntityClassification (
 entity_classification_id         NUMBER(12) NOT NULL,
 entity_attributes_id         NUMBER(12) NOT NULL,
 entity_type_id               NUMBER(12) NOT NULL,
 modification_date            DATE NOT NULL,
 user_read                    NUMBER(1) NOT NULL,
 user_write                   NUMBER(1) NOT NULL,
 group_read                   NUMBER(1) NOT NULL,
 group_write                  NUMBER(1) NOT NULL,
 other_read                   NUMBER(1) NOT NULL,
 other_write                  NUMBER(1) NOT NULL,
 row_user_id                  NUMBER(12) NOT NULL,
 row_group_id                 NUMBER(3) NOT NULL,
 row_project_id               NUMBER(4) NOT NULL,
 row_alg_invocation_id        NUMBER(12) NOT NULL,
 FOREIGN KEY (entity_type_id) REFERENCES &1..EntityType,
 FOREIGN KEY (entity_attributes_id) REFERENCES &1..EntityAttributes,
 PRIMARY KEY (entity_classification_id)
);

CREATE INDEX &1..entityclassification_ix_1 ON &1..entityclassification (entity_type_id, entity_attributes_id) TABLESPACE indx;
CREATE INDEX &1..entityclassification_ix_2 ON &1..entityclassification (entity_attributes_id, entity_type_id) TABLESPACE indx;

GRANT INSERT, SELECT, UPDATE, DELETE ON &1..EntityClassification TO gus_w;
GRANT SELECT ON &1..EntityClassification TO gus_r;

CREATE SEQUENCE &1..EntityClassification_sq;
GRANT SELECT ON &1..EntityClassification_sq TO gus_w;
GRANT SELECT ON &1..EntityClassification_sq TO gus_r;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'EntityClassification',
       'Standard', 'entity_classification_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = lower('&1')) d
WHERE 'entityclassification' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

-----------------------------------------------------------

CREATE TABLE &1..ProcessAttributes (
 process_attributes_id           NUMBER(12) NOT NULL,
 process_type_id                NUMBER(12) NOT NULL,
 in_entity_id                 NUMBER(12) NOT NULL,
 out_entity_id                NUMBER(12) NOT NULL,
 atts                         CLOB,
 modification_date            DATE NOT NULL,
 user_read                    NUMBER(1) NOT NULL,
 user_write                   NUMBER(1) NOT NULL,
 group_read                   NUMBER(1) NOT NULL,
 group_write                  NUMBER(1) NOT NULL,
 other_read                   NUMBER(1) NOT NULL,
 other_write                  NUMBER(1) NOT NULL,
 row_user_id                  NUMBER(12) NOT NULL,
 row_group_id                 NUMBER(3) NOT NULL,
 row_project_id               NUMBER(4) NOT NULL,
 row_alg_invocation_id        NUMBER(12) NOT NULL,
 FOREIGN KEY (in_entity_id) REFERENCES &1..entityattributes,
 FOREIGN KEY (out_entity_id) REFERENCES &1..entityattributes,
 FOREIGN KEY (process_type_id) REFERENCES &1..processtype,
 PRIMARY KEY (process_attributes_id),
 CONSTRAINT ensure_ea_json CHECK (atts is json)   
);

CREATE INDEX &1..ea_in_ix ON &1..processattributes (in_entity_id, out_entity_id, process_attributes_id) tablespace indx;
CREATE INDEX &1..ea_out_ix ON &1..processattributes (out_entity_id, in_entity_id, process_attributes_id) tablespace indx;

CREATE INDEX &1..ea_ix_1 ON &1..processattributes (process_type_id, process_attributes_id) TABLESPACE indx;

GRANT INSERT, SELECT, UPDATE, DELETE ON &1..ProcessAttributes TO gus_w;
GRANT SELECT ON &1..ProcessAttributes TO gus_r;

CREATE SEQUENCE &1..ProcessAttributes_sq;
GRANT SELECT ON &1..ProcessAttributes_sq TO gus_w;
GRANT SELECT ON &1..ProcessAttributes_sq TO gus_r;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'ProcessAttributes',
       'Standard', 'process_attributes_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = lower('&1')) d
WHERE 'processattributes' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

-----------------------------------------------------------

CREATE TABLE &1..EntityTypeGraph (
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
 modification_date            DATE NOT NULL,
 user_read                    NUMBER(1) NOT NULL,
 user_write                   NUMBER(1) NOT NULL,
 group_read                   NUMBER(1) NOT NULL,
 group_write                  NUMBER(1) NOT NULL,
 other_read                   NUMBER(1) NOT NULL,
 other_write                  NUMBER(1) NOT NULL,
 row_user_id                  NUMBER(12) NOT NULL,
 row_group_id                 NUMBER(3) NOT NULL,
 row_project_id               NUMBER(4) NOT NULL,
 row_alg_invocation_id        NUMBER(12) NOT NULL,
 FOREIGN KEY (study_id) REFERENCES &1..study,
 FOREIGN KEY (parent_id) REFERENCES &1..entitytype,
 FOREIGN KEY (entity_type_id) REFERENCES &1..entitytype,
 PRIMARY KEY (entity_type_graph_id)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON &1..EntityTypeGraph TO gus_w;
GRANT SELECT ON &1..EntityTypeGraph TO gus_r;

CREATE SEQUENCE &1..EntityTypeGraph_sq;
GRANT SELECT ON &1..EntityTypeGraph_sq TO gus_w;
GRANT SELECT ON &1..EntityTypeGraph_sq TO gus_r;

CREATE INDEX &1..entitytypegraph_ix_1 ON &1..entitytypegraph (study_id, entity_type_id, parent_id, entity_type_graph_id) TABLESPACE indx;
CREATE INDEX &1..entitytypegraph_ix_2 ON &1..entitytypegraph (parent_id, entity_type_graph_id) TABLESPACE indx;
CREATE INDEX &1..entitytypegraph_ix_3 ON &1..entitytypegraph (entity_type_id, entity_type_graph_id) TABLESPACE indx;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'EntityTypeGraph',
       'Standard', 'entity_type_graph_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = lower('&1')) d
WHERE 'entitytypegraph' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);


-----------------------------------------------------------

CREATE TABLE &1..AttributeUnit (
 attribute_unit_id                NUMBER(12) NOT NULL,
 entity_type_id                      NUMBER(12) NOT NULL,
 attr_ontology_term_id               NUMBER(10) NOT NULL,
 unit_ontology_term_id               NUMBER(10) NOT NULL,
 modification_date            DATE NOT NULL,
 user_read                    NUMBER(1) NOT NULL,
 user_write                   NUMBER(1) NOT NULL,
 group_read                   NUMBER(1) NOT NULL,
 group_write                  NUMBER(1) NOT NULL,
 other_read                   NUMBER(1) NOT NULL,
 other_write                  NUMBER(1) NOT NULL,
 row_user_id                  NUMBER(12) NOT NULL,
 row_group_id                 NUMBER(3) NOT NULL,
 row_project_id               NUMBER(4) NOT NULL,
 row_alg_invocation_id        NUMBER(12) NOT NULL,
 FOREIGN KEY (entity_type_id) REFERENCES &1..EntityType,
FOREIGN KEY (attr_ontology_term_id) REFERENCES &2..ontologyterm,
FOREIGN KEY (unit_ontology_term_id) REFERENCES &2..ontologyterm,
 PRIMARY KEY (attribute_unit_id)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON &1..AttributeUnit TO gus_w;
GRANT SELECT ON &1..AttributeUnit TO gus_r;

CREATE SEQUENCE &1..AttributeUnit_sq;
GRANT SELECT ON &1..AttributeUnit_sq TO gus_w;
GRANT SELECT ON &1..AttributeUnit_sq TO gus_r;

CREATE INDEX &1..attributeunit_ix_1 ON &1..attributeunit (entity_type_id, attr_ontology_term_id, unit_ontology_term_id, attribute_unit_id) TABLESPACE indx;
CREATE INDEX &1..attributeunit_ix_2 ON &1..attributeunit (attr_ontology_term_id, attribute_unit_id) TABLESPACE indx;
CREATE INDEX &1..attributeunit_ix_3 ON &1..attributeunit (unit_ontology_term_id, attribute_unit_id) TABLESPACE indx;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'AttributeUnit',
       'Standard', 'attribute_unit_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = lower('&1')) d
WHERE 'attributeunit' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

-----------------------------------------------------------


CREATE TABLE &1..ProcessTypeComponent (
 process_type_component_id       NUMBER(12) NOT NULL,
 process_type_id                 NUMBER(12) NOT NULL,
 component_id                 NUMBER(12) NOT NULL,
 order_num                    NUMBER(2) NOT NULL,
 modification_date            DATE NOT NULL,
 user_read                    NUMBER(1) NOT NULL,
 user_write                   NUMBER(1) NOT NULL,
 group_read                   NUMBER(1) NOT NULL,
 group_write                  NUMBER(1) NOT NULL,
 other_read                   NUMBER(1) NOT NULL,
 other_write                  NUMBER(1) NOT NULL,
 row_user_id                  NUMBER(12) NOT NULL,
 row_group_id                 NUMBER(3) NOT NULL,
 row_project_id               NUMBER(4) NOT NULL,
 row_alg_invocation_id        NUMBER(12) NOT NULL,
 FOREIGN KEY (process_type_id) REFERENCES &1..ProcessType,
 FOREIGN KEY (component_id) REFERENCES &1..ProcessType,
 PRIMARY KEY (process_type_component_id)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON &1..ProcessTypeComponent TO gus_w;
GRANT SELECT ON &1..ProcessTypeComponent TO gus_r;

CREATE SEQUENCE &1..ProcessTypeComponent_sq;
GRANT SELECT ON &1..ProcessTypeComponent_sq TO gus_w;
GRANT SELECT ON &1..ProcessTypeComponent_sq TO gus_r;

CREATE INDEX &1..ptc_ix_1 ON &1..processtypecomponent (process_type_id, component_id, order_num, process_type_component_id) TABLESPACE indx;
CREATE INDEX &1..ptc_ix_2 ON &1..processtypecomponent (component_id, process_type_component_id) TABLESPACE indx;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'ProcessTypeComponent',
       'Standard', 'process_type_component_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = lower('&1')) d
WHERE 'processtypecomponent' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);


-----------------------------------------------------------


CREATE TABLE &1..Attribute (
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
  modification_date            DATE NOT NULL,
  user_read                    NUMBER(1) NOT NULL,
  user_write                   NUMBER(1) NOT NULL,
  group_read                   NUMBER(1) NOT NULL,
  group_write                  NUMBER(1) NOT NULL,
  other_read                   NUMBER(1) NOT NULL,
  other_write                  NUMBER(1) NOT NULL,
  row_user_id                  NUMBER(12) NOT NULL,
  row_group_id                 NUMBER(3) NOT NULL,
  row_project_id               NUMBER(4) NOT NULL,
  row_alg_invocation_id        NUMBER(12) NOT NULL,
  FOREIGN KEY (entity_type_id) REFERENCES &1..EntityType,
  FOREIGN KEY (process_type_id) REFERENCES &1..ProcessType,
 FOREIGN KEY (ontology_term_id) REFERENCES &2..ontologyterm,
 FOREIGN KEY (unit_ontology_term_id) REFERENCES &2..ontologyterm,
  PRIMARY KEY (attribute_id),
  CONSTRAINT ensure_ov_json CHECK (ordered_values is json)   
);

GRANT INSERT, SELECT, UPDATE, DELETE ON &1..Attribute TO gus_w;
GRANT SELECT ON &1..Attribute TO gus_r;

CREATE SEQUENCE &1..Attribute_sq;
GRANT SELECT ON &1..Attribute_sq TO gus_w;
GRANT SELECT ON &1..Attribute_sq TO gus_r;

CREATE INDEX &1..attribute_ix_1 ON &1..attribute (entity_type_id, process_type_id, stable_id, attribute_id) TABLESPACE indx;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'Attribute',
       'Standard', 'attribute_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = lower('&1')) d
WHERE 'attribute' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);



-----------------------------------------------------------

CREATE TABLE &1..AttributeGraph (
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
  force_string_type            varchar2(10),
  variable_spec_to_impute_zeroes_for     varchar2(200),
  has_study_dependent_vocabulary         number(1),
  weighting_variable_spec                varchar2(200),
  is_repeated                  number(1),
  bin_width_override           varchar2(16),
  is_temporal                  number(1),
  is_featured                  number(1),
  ordinal_values               CLOB,
  scale                         varchar2(30),
  modification_date            DATE NOT NULL,
  user_read                    NUMBER(1) NOT NULL,
  user_write                   NUMBER(1) NOT NULL,
  group_read                   NUMBER(1) NOT NULL,
  group_write                  NUMBER(1) NOT NULL,
  other_read                   NUMBER(1) NOT NULL,
  other_write                  NUMBER(1) NOT NULL,
  row_user_id                  NUMBER(12) NOT NULL,
  row_group_id                 NUMBER(3) NOT NULL,
  row_project_id               NUMBER(4) NOT NULL,
  row_alg_invocation_id        NUMBER(12) NOT NULL,
 FOREIGN KEY (ontology_term_id) REFERENCES &2..ontologyterm,
 FOREIGN KEY (parent_ontology_term_id) REFERENCES &2..ontologyterm,
  FOREIGN KEY (study_id) REFERENCES &1..study,
  PRIMARY KEY (attribute_graph_id),
  CONSTRAINT ensure_ordv_json CHECK (ordinal_values is json),
  CONSTRAINT ensure_prolbl_json CHECK (provider_label is json)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON &1..AttributeGraph TO gus_w;
GRANT SELECT ON &1..AttributeGraph TO gus_r;

CREATE SEQUENCE &1..AttributeGraph_sq;
GRANT SELECT ON &1..AttributeGraph_sq TO gus_w;
GRANT SELECT ON &1..AttributeGraph_sq TO gus_r;

CREATE INDEX &1..attributegraph_ix_1 ON &1..attributegraph (study_id, ontology_term_id, parent_ontology_term_id, attribute_graph_id) TABLESPACE indx;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'AttributeGraph',
       'Standard', 'attribute_graph_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = lower('&1')) d
WHERE 'attributegraph' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);


CREATE TABLE &1..StudyCharacteristic (
  study_characteristic_id      NUMBER(5) NOT NULL,
  study_id                     NUMBER(12) NOT NULL, 
  attribute_id                 NUMBER(12) NOT NULL,
  value_ontology_term_id       NUMBER(10),
  value                        VARCHAR2(300) NOT NULL,
  modification_date            DATE NOT NULL,
  user_read                    NUMBER(1) NOT NULL,
  user_write                   NUMBER(1) NOT NULL,
  group_read                   NUMBER(1) NOT NULL,
  group_write                  NUMBER(1) NOT NULL,
  other_read                   NUMBER(1) NOT NULL,
  other_write                  NUMBER(1) NOT NULL,
  row_user_id                  NUMBER(12) NOT NULL,
  row_group_id                 NUMBER(3) NOT NULL,
  row_project_id               NUMBER(4) NOT NULL,
  row_alg_invocation_id        NUMBER(12) NOT NULL,
 FOREIGN KEY (value_ontology_term_id) REFERENCES &2..ontologyterm,
 FOREIGN KEY (attribute_id) REFERENCES &2..ontologyterm,
  FOREIGN KEY (study_id) REFERENCES &1..study,
  PRIMARY KEY (study_characteristic_id)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON &1..StudyCharacteristic TO gus_w;
GRANT SELECT ON &1..StudyCharacteristic TO gus_r;

CREATE SEQUENCE &1..StudyCharacteristic_sq;
GRANT SELECT ON &1..StudyCharacteristic_sq TO gus_w;
GRANT SELECT ON &1..StudyCharacteristic_sq TO gus_r;

CREATE INDEX &1..StudyCharacteristic_ix_1 ON &1..StudyCharacteristic (study_id, attribute_id, value) TABLESPACE indx;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'StudyCharacteristic',
       'Standard', 'study_characteristic_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = lower('&1')) d
WHERE 'study_characteristic_id' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);


-- for mega study, we need to prefix the stable id with the study stable id (bfv=big fat view)
create or replace view &1..entityattributes_bfv as
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
from &1..entityclassification ec
   , &1..entityattributes ea
   , &1..entitytype et
   , &1..study s
   , &1..entitytype et2
   , &1..study s2
 where ec.entity_attributes_id = ea.entity_attributes_id
and ec.entity_type_id = et.entity_type_id
and et.study_id = s.study_id
and ea.ENTITY_TYPE_ID = et2.entity_type_id
and et2.study_id = s2.study_id;

GRANT select ON &1..entityattributes_bfv TO gus_r;
GRANT select ON &1..entityattributes_bfv TO gus_w;

CREATE TABLE &1..AnnotationProperties (
  annotation_properties_id   NUMBER(10) NOT NULL,
  ontology_term_id       NUMBER(10) NOT NULL,
  study_id            NUMBER(12) NOT NULL,
  props                         CLOB,
 external_database_release_id number(10) NOT NULL,
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
  FOREIGN KEY (ontology_term_id) REFERENCES &2..OntologyTerm (ontology_term_id),
  FOREIGN KEY (study_id) REFERENCES &1..study (study_id),
 FOREIGN KEY (external_database_release_id) REFERENCES &2..ExternalDatabaseRelease,
PRIMARY KEY (annotation_properties_id),
  CONSTRAINT ensure_anp_json CHECK (props is json)
);

CREATE SEQUENCE &1..AnnotationProperties_sq;

GRANT insert, select, update, delete ON &1..AnnotationProperties TO gus_w;
GRANT select ON &1..AnnotationProperties TO gus_r;
GRANT select ON &1..AnnotationProperties_sq TO gus_w;


INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable,
     modification_date, user_read, user_write, group_read, group_write,
     other_read, other_write, row_user_id, row_group_id, row_project_id,
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'AnnotationProperties',
       'Standard', 'annotation_properties_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = lower('&1')) d
WHERE 'annotationproperties' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);



exit;
