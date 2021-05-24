CREATE TABLE apidb.Study (
 study_id            NUMBER(12) NOT NULL,
 stable_id                         VARCHAR2(200) NOT NULL,
 external_database_release_id number(10) NOT NULL,
 internal_abbrev              varchar2(50),
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
 FOREIGN KEY (external_database_release_id) REFERENCES sres.ExternalDatabaseRelease,
 PRIMARY KEY (study_id),
 CONSTRAINT unique_stable_id UNIQUE (stable_id)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.Study TO gus_w;
GRANT SELECT ON apidb.Study TO gus_r;

CREATE SEQUENCE apidb.Study_sq;
GRANT SELECT ON apidb.Study_sq TO gus_w;
GRANT SELECT ON apidb.Study_sq TO gus_r;

CREATE INDEX apidb.study_ix_1 ON apidb.study (external_database_release_id, stable_id, internal_abbrev, study_id) TABLESPACE indx;

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
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'study' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

-----------------------------------------------------------

CREATE TABLE apidb.EntityType (
 entity_type_id            NUMBER(12) NOT NULL,
 name                      VARCHAR2(200) NOT NULL,
 type_id                   NUMBER(10),
 isa_type                     VARCHAR2(50),
 study_id            NUMBER(12) NOT NULL,
 internal_abbrev              VARCHAR2(50) NOT NULL,
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
 FOREIGN KEY (study_id) REFERENCES apidb.study,
 FOREIGN KEY (type_id) REFERENCES sres.ontologyterm,
 PRIMARY KEY (entity_type_id)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.EntityType TO gus_w;
GRANT SELECT ON apidb.EntityType TO gus_r;

CREATE SEQUENCE apidb.EntityType_sq;
GRANT SELECT ON apidb.EntityType_sq TO gus_w;
GRANT SELECT ON apidb.EntityType_sq TO gus_r;

CREATE INDEX apidb.entitytype_ix_1 ON apidb.entitytype (study_id, entity_type_id) TABLESPACE indx;
CREATE INDEX apidb.entitytype_ix_2 ON apidb.entitytype (type_id, entity_type_id) TABLESPACE indx;

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
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'entitytype' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

-----------------------------------------------------------

CREATE TABLE apidb.ProcessType (
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
 FOREIGN KEY (type_id) REFERENCES sres.ontologyterm,
 PRIMARY KEY (process_type_id)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.ProcessType TO gus_w;
GRANT SELECT ON apidb.ProcessType TO gus_r;

CREATE SEQUENCE apidb.ProcessType_sq;
GRANT SELECT ON apidb.ProcessType_sq TO gus_w;
GRANT SELECT ON apidb.ProcessType_sq TO gus_r;

CREATE INDEX apidb.processtype_ix_1 ON apidb.processtype (type_id, process_type_id) TABLESPACE indx;

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
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'processtype' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

-----------------------------------------------------------

CREATE TABLE apidb.EntityAttributes (
 entity_attributes_id         NUMBER(12) NOT NULL,
 stable_id                         VARCHAR2(200) NOT NULL,
 entity_type_id                    NUMBER(12) NOT NULL,
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
 FOREIGN KEY (entity_type_id) REFERENCES apidb.EntityType,
 PRIMARY KEY (entity_attributes_id),
 CONSTRAINT ensure_va_json CHECK (atts is json)   
);

-- 
--CREATE SEARCH INDEX apidb.va_search_ix ON apidb.entityattributes (atts) FOR JSON;

CREATE INDEX apidb.entityattributes_ix_1 ON apidb.entityattributes (entity_type_id, entity_attributes_id) TABLESPACE indx;

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.EntityAttributes TO gus_w;
GRANT SELECT ON apidb.EntityAttributes TO gus_r;

CREATE SEQUENCE apidb.EntityAttributes_sq;
GRANT SELECT ON apidb.EntityAttributes_sq TO gus_w;
GRANT SELECT ON apidb.EntityAttributes_sq TO gus_r;

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
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'entityattributes' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

-----------------------------------------------------------

CREATE TABLE apidb.ProcessAttributes (
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
 FOREIGN KEY (in_entity_id) REFERENCES apidb.entityattributes,
 FOREIGN KEY (out_entity_id) REFERENCES apidb.entityattributes,
 FOREIGN KEY (process_type_id) REFERENCES apidb.processtype,
 PRIMARY KEY (process_attributes_id),
 CONSTRAINT ensure_ea_json CHECK (atts is json)   
);

CREATE INDEX apidb.ea_in_ix ON apidb.processattributes (in_entity_id, out_entity_id, process_attributes_id) tablespace indx;
CREATE INDEX apidb.ea_out_ix ON apidb.processattributes (out_entity_id, in_entity_id, process_attributes_id) tablespace indx;

CREATE INDEX apidb.ea_ix_1 ON apidb.processattributes (process_type_id, process_attributes_id) TABLESPACE indx;

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.ProcessAttributes TO gus_w;
GRANT SELECT ON apidb.ProcessAttributes TO gus_r;

CREATE SEQUENCE apidb.ProcessAttributes_sq;
GRANT SELECT ON apidb.ProcessAttributes_sq TO gus_w;
GRANT SELECT ON apidb.ProcessAttributes_sq TO gus_r;

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
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'processattributes' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

-----------------------------------------------------------

CREATE TABLE apidb.EntityTypeGraph (
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
 FOREIGN KEY (study_id) REFERENCES apidb.study,
 FOREIGN KEY (parent_id) REFERENCES apidb.entitytype,
 FOREIGN KEY (entity_type_id) REFERENCES apidb.entitytype,
 PRIMARY KEY (entity_type_graph_id)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.EntityTypeGraph TO gus_w;
GRANT SELECT ON apidb.EntityTypeGraph TO gus_r;

CREATE SEQUENCE apidb.EntityTypeGraph_sq;
GRANT SELECT ON apidb.EntityTypeGraph_sq TO gus_w;
GRANT SELECT ON apidb.EntityTypeGraph_sq TO gus_r;

CREATE INDEX apidb.entitytypegraph_ix_1 ON apidb.entitytypegraph (study_id, entity_type_id, parent_id, entity_type_graph_id) TABLESPACE indx;
CREATE INDEX apidb.entitytypegraph_ix_2 ON apidb.entitytypegraph (parent_id, entity_type_graph_id) TABLESPACE indx;
CREATE INDEX apidb.entitytypegraph_ix_3 ON apidb.entitytypegraph (entity_type_id, entity_type_graph_id) TABLESPACE indx;

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
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'entitytypegraph' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);


-----------------------------------------------------------

CREATE TABLE apidb.AttributeUnit (
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
 FOREIGN KEY (entity_type_id) REFERENCES apidb.EntityType,
 FOREIGN KEY (attr_ontology_term_id) REFERENCES sres.ontologyterm,
 FOREIGN KEY (unit_ontology_term_id) REFERENCES sres.ontologyterm,
 PRIMARY KEY (attribute_unit_id)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.AttributeUnit TO gus_w;
GRANT SELECT ON apidb.AttributeUnit TO gus_r;

CREATE SEQUENCE apidb.AttributeUnit_sq;
GRANT SELECT ON apidb.AttributeUnit_sq TO gus_w;
GRANT SELECT ON apidb.AttributeUnit_sq TO gus_r;

CREATE INDEX apidb.attributeunit_ix_1 ON apidb.attributeunit (entity_type_id, attr_ontology_term_id, unit_ontology_term_id, attribute_unit_id) TABLESPACE indx;
CREATE INDEX apidb.attributeunit_ix_2 ON apidb.attributeunit (attr_ontology_term_id, attribute_unit_id) TABLESPACE indx;
CREATE INDEX apidb.attributeunit_ix_3 ON apidb.attributeunit (unit_ontology_term_id, attribute_unit_id) TABLESPACE indx;

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
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'attributeunit' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

-----------------------------------------------------------


CREATE TABLE apidb.ProcessTypeComponent (
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
 FOREIGN KEY (process_type_id) REFERENCES apidb.ProcessType,
 FOREIGN KEY (component_id) REFERENCES apidb.ProcessType,
 PRIMARY KEY (process_type_component_id)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.ProcessTypeComponent TO gus_w;
GRANT SELECT ON apidb.ProcessTypeComponent TO gus_r;

CREATE SEQUENCE apidb.ProcessTypeComponent_sq;
GRANT SELECT ON apidb.ProcessTypeComponent_sq TO gus_w;
GRANT SELECT ON apidb.ProcessTypeComponent_sq TO gus_r;

CREATE INDEX apidb.ptc_ix_1 ON apidb.processtypecomponent (process_type_id, component_id, order_num, process_type_component_id) TABLESPACE indx;
CREATE INDEX apidb.ptc_ix_2 ON apidb.processtypecomponent (component_id, process_type_component_id) TABLESPACE indx;

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
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'processtypecomponent' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);


-----------------------------------------------------------

CREATE TABLE apidb.AttributeValue (
 attribute_value_id           NUMBER(12) NOT NULL,
 entity_attributes_id         NUMBER(12) NOT NULL,
 entity_type_id               NUMBER(12) NOT NULL,
 incoming_process_type_id        NUMBER(12),
 attribute_stable_id                VARCHAR(255)  NOT NULL, 
 string_value                 VARCHAR(1000),
 number_value                 NUMBER,
 date_value                   DATE, 
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
 FOREIGN KEY (entity_attributes_id) REFERENCES apidb.EntityAttributes,
 FOREIGN KEY (entity_type_id) REFERENCES apidb.EntityType,
 FOREIGN KEY (incoming_process_type_id) REFERENCES apidb.ProcessType,
 PRIMARY KEY (attribute_value_id)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.AttributeValue TO gus_w;
GRANT SELECT ON apidb.AttributeValue TO gus_r;

CREATE SEQUENCE apidb.AttributeValue_sq;
GRANT SELECT ON apidb.AttributeValue_sq TO gus_w;
GRANT SELECT ON apidb.AttributeValue_sq TO gus_r;

CREATE INDEX apidb.attributevalue_ix_1 ON apidb.attributevalue (entity_type_id, incoming_process_type_id, attribute_stable_id, entity_attributes_id) TABLESPACE indx;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'AttributeValue',
       'Standard', 'attribute_value_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'attributevalue' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

-----------------------------------------------------------

CREATE TABLE apidb.Attribute (
  attribute_id                  NUMBER(12) NOT NULL,
  entity_type_id                NUMBER(12) not null,
  entity_type_stable_id         varchar2(255),
  process_type_id                 NUMBER(12),
  ontology_term_id         NUMBER(10),
  parent_ontology_term_id         NUMBER(10) NOT NULL,
  attribute_stable_id varchar2(255) NOT NULL,
  provider_label                varchar(1500),
  display_name                  varchar(1500) not null,
  data_type                    varchar2(10) not null,
  distinct_values_count            integer,
  is_multi_valued                number(1),
  data_shape                     varchar2(30),
  unit                          varchar2(30),
  unit_ontology_term_id         NUMBER(10),
  precision                     integer,
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
  FOREIGN KEY (entity_type_id) REFERENCES apidb.EntityType,
  FOREIGN KEY (process_type_id) REFERENCES apidb.ProcessType,
  FOREIGN KEY (ontology_term_id) REFERENCES sres.ontologyterm,
  FOREIGN KEY (parent_ontology_term_id) REFERENCES sres.ontologyterm,
  FOREIGN KEY (unit_ontology_term_id) REFERENCES sres.ontologyterm,
  PRIMARY KEY (attribute_id)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.Attribute TO gus_w;
GRANT SELECT ON apidb.Attribute TO gus_r;

CREATE SEQUENCE apidb.Attribute_sq;
GRANT SELECT ON apidb.Attribute_sq TO gus_w;
GRANT SELECT ON apidb.Attribute_sq TO gus_r;

CREATE INDEX apidb.attribute_ix_1 ON apidb.attribute (entity_type_id, process_type_id, parent_ontology_term_id, attribute_stable_id, attribute_id) TABLESPACE indx;

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
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'attribute' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);



-----------------------------------------------------------

CREATE TABLE apidb.AttributeGraph (
  attribute_graph_id                  NUMBER(12) NOT NULL,
  study_id            NUMBER(12) NOT NULL, 
  ontology_term_id         NUMBER(10) NOT NULL,
  stable_id                varchar2(255) NOT NULL,
  parent_stable_id              varchar2(255) NOT NULL,
  parent_ontology_term_id       NUMBER(10) NOT NULL,
  provider_label                varchar(1500),
  display_name                  varchar(1500) not null,
  term_type                    varchar2(20),
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
  FOREIGN KEY (ontology_term_id) REFERENCES sres.ontologyterm,
  FOREIGN KEY (parent_ontology_term_id) REFERENCES sres.ontologyterm,
  FOREIGN KEY (study_id) REFERENCES apidb.study,
  PRIMARY KEY (attribute_graph_id)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.AttributeGraph TO gus_w;
GRANT SELECT ON apidb.AttributeGraph TO gus_r;

CREATE SEQUENCE apidb.AttributeGraph_sq;
GRANT SELECT ON apidb.AttributeGraph_sq TO gus_w;
GRANT SELECT ON apidb.AttributeGraph_sq TO gus_r;

CREATE INDEX apidb.attributegraph_ix_1 ON apidb.attributegraph (study_id, ontology_term_id, parent_ontology_term_id, attribute_graph_id) TABLESPACE indx;

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
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'attributegraph' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);



exit;
