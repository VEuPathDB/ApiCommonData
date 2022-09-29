-- set CONCAT OFF;

-- so the foreign key constraints are allowed
--grant references on sres.OntologyTerm to :SCHEMA_PREFIX;
--grant references on sres.ExternalDatabaseRelease to :SCHEMA_PREFIX;

CREATE TABLE :SCHEMA_PREFIX.Study (
 study_id            NUMERIC(12) NOT NULL,
 stable_id                         VARCHAR(200) NOT NULL,
 external_database_release_id NUMERIC(10) NOT NULL,
 internal_abbrev              VARCHAR(50),
 max_attr_length              NUMERIC(4),
 modification_date            DATE NOT NULL,
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
 FOREIGN KEY (external_database_release_id) REFERENCES sres.ExternalDatabaseRelease,
 PRIMARY KEY (study_id),
 CONSTRAINT unique_stable_id UNIQUE (stable_id)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON :SCHEMA_PREFIX.Study TO gus_w;
GRANT SELECT ON :SCHEMA_PREFIX.Study TO gus_r;

CREATE SEQUENCE :SCHEMA_PREFIX.Study_sq;
GRANT SELECT ON :SCHEMA_PREFIX.Study_sq TO gus_w;
GRANT SELECT ON :SCHEMA_PREFIX.Study_sq TO gus_r;

CREATE INDEX study_ix_1 ON :SCHEMA_PREFIX.study (external_database_release_id, stable_id, internal_abbrev, study_id) TABLESPACE indx;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'Study',
       'Standard', 'study_id',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM 
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = lower(':SCHEMA_PREFIX')) d
WHERE 'study' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

-----------------------------------------------------------

CREATE TABLE :SCHEMA_PREFIX.EntityType (
 entity_type_id            NUMERIC(12) NOT NULL,
 name                      VARCHAR(200) NOT NULL,
 type_id                   NUMERIC(10),
 isa_type                     VARCHAR(50),
 study_id            NUMERIC(12) NOT NULL,
 internal_abbrev              VARCHAR(50) NOT NULL,
 cardinality                  NUMERIC(38,0),
 modification_date            DATE NOT NULL,
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
 FOREIGN KEY (study_id) REFERENCES :SCHEMA_PREFIX.study,
 FOREIGN KEY (type_id) REFERENCES sres.ontologyterm,
 PRIMARY KEY (entity_type_id)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON :SCHEMA_PREFIX.EntityType TO gus_w;
GRANT SELECT ON :SCHEMA_PREFIX.EntityType TO gus_r;

CREATE SEQUENCE :SCHEMA_PREFIX.EntityType_sq;
GRANT SELECT ON :SCHEMA_PREFIX.EntityType_sq TO gus_w;
GRANT SELECT ON :SCHEMA_PREFIX.EntityType_sq TO gus_r;

CREATE UNIQUE INDEX entitytype_ix_1 ON :SCHEMA_PREFIX.entitytype (study_id, entity_type_id) TABLESPACE indx;
CREATE UNIQUE INDEX entitytype_ix_2 ON :SCHEMA_PREFIX.entitytype (type_id, entity_type_id) TABLESPACE indx;
CREATE UNIQUE INDEX entitytype_ix_3 ON :SCHEMA_PREFIX.entitytype (study_id, internal_abbrev) TABLESPACE indx;


INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'EntityType',
       'Standard', 'entity_type_id',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM 
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = lower(':SCHEMA_PREFIX')) d
WHERE 'entitytype' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

-----------------------------------------------------------

CREATE TABLE :SCHEMA_PREFIX.ProcessType (
 process_type_id            NUMERIC(12) NOT NULL,
 name                         VARCHAR(200) NOT NULL,
 description                  VARCHAR(4000),
 type_id                      NUMERIC(10),
 modification_date            DATE NOT NULL,
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
 FOREIGN KEY (type_id) REFERENCES sres.ontologyterm,
 PRIMARY KEY (process_type_id)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON :SCHEMA_PREFIX.ProcessType TO gus_w;
GRANT SELECT ON :SCHEMA_PREFIX.ProcessType TO gus_r;

CREATE SEQUENCE :SCHEMA_PREFIX.ProcessType_sq;
GRANT SELECT ON :SCHEMA_PREFIX.ProcessType_sq TO gus_w;
GRANT SELECT ON :SCHEMA_PREFIX.ProcessType_sq TO gus_r;

CREATE INDEX processtype_ix_1 ON :SCHEMA_PREFIX.processtype (type_id, process_type_id) TABLESPACE indx;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'ProcessType',
       'Standard', 'process_type_id',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM 
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = lower(':SCHEMA_PREFIX')) d
WHERE 'processtype' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

-----------------------------------------------------------

CREATE TABLE :SCHEMA_PREFIX.EntityAttributes (
 entity_attributes_id         NUMERIC(12) NOT NULL,
 stable_id                         VARCHAR(200) NOT NULL,
 entity_type_id                    NUMERIC(12) NOT NULL,
 atts                         TEXT,
 modification_date            DATE NOT NULL,
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
 FOREIGN KEY (entity_type_id) REFERENCES :SCHEMA_PREFIX.EntityType,
 PRIMARY KEY (entity_attributes_id)

);
-- TODO Add back the is json constraint
--,CONSTRAINT ensure_va_json CHECK (atts is json)

-- 
--CREATE SEARCH INDEX va_search_ix ON :SCHEMA_PREFIX.entityattributes (atts) FOR JSON;

CREATE INDEX entityattributes_ix_1 ON :SCHEMA_PREFIX.entityattributes (entity_type_id, entity_attributes_id) TABLESPACE indx;

GRANT INSERT, SELECT, UPDATE, DELETE ON :SCHEMA_PREFIX.EntityAttributes TO gus_w;
GRANT SELECT ON :SCHEMA_PREFIX.EntityAttributes TO gus_r;

CREATE SEQUENCE :SCHEMA_PREFIX.EntityAttributes_sq;
GRANT SELECT ON :SCHEMA_PREFIX.EntityAttributes_sq TO gus_w;
GRANT SELECT ON :SCHEMA_PREFIX.EntityAttributes_sq TO gus_r;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'EntityAttributes',
       'Standard', 'entity_attributes_id',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM 
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = lower(':SCHEMA_PREFIX')) d
WHERE 'entityattributes' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

-----------------------------------------------------------

CREATE TABLE :SCHEMA_PREFIX.ProcessAttributes (
 process_attributes_id           NUMERIC(12) NOT NULL,
 process_type_id                NUMERIC(12) NOT NULL,
 in_entity_id                 NUMERIC(12) NOT NULL,
 out_entity_id                NUMERIC(12) NOT NULL,
 atts                         TEXT,
 modification_date            DATE NOT NULL,
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
 FOREIGN KEY (in_entity_id) REFERENCES :SCHEMA_PREFIX.entityattributes,
 FOREIGN KEY (out_entity_id) REFERENCES :SCHEMA_PREFIX.entityattributes,
 FOREIGN KEY (process_type_id) REFERENCES :SCHEMA_PREFIX.processtype,
 PRIMARY KEY (process_attributes_id)

);
-- TODO Add back the is json constraint
--, CONSTRAINT ensure_ea_json CHECK (atts is json)

CREATE INDEX ea_in_ix ON :SCHEMA_PREFIX.processattributes (in_entity_id, out_entity_id, process_attributes_id) tablespace indx;
CREATE INDEX ea_out_ix ON :SCHEMA_PREFIX.processattributes (out_entity_id, in_entity_id, process_attributes_id) tablespace indx;

CREATE INDEX ea_ix_1 ON :SCHEMA_PREFIX.processattributes (process_type_id, process_attributes_id) TABLESPACE indx;

GRANT INSERT, SELECT, UPDATE, DELETE ON :SCHEMA_PREFIX.ProcessAttributes TO gus_w;
GRANT SELECT ON :SCHEMA_PREFIX.ProcessAttributes TO gus_r;

CREATE SEQUENCE :SCHEMA_PREFIX.ProcessAttributes_sq;
GRANT SELECT ON :SCHEMA_PREFIX.ProcessAttributes_sq TO gus_w;
GRANT SELECT ON :SCHEMA_PREFIX.ProcessAttributes_sq TO gus_r;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'ProcessAttributes',
       'Standard', 'process_attributes_id',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM 
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = lower(':SCHEMA_PREFIX')) d
WHERE 'processattributes' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

-----------------------------------------------------------

CREATE TABLE :SCHEMA_PREFIX.EntityTypeGraph (
 entity_type_graph_id           NUMERIC(12) NOT NULL,
 study_id                       NUMERIC(12) NOT NULL,
 study_stable_id                VARCHAR(200),
 parent_stable_id             VARCHAR(255),
 parent_id                    NUMERIC(12),
 stable_id                    VARCHAR(255),
 entity_type_id                NUMERIC(12) NOT NULL,
 display_name                 VARCHAR(200) NOT NULL,
 display_name_plural          VARCHAR(200),
 description                  VARCHAR(4000),
 internal_abbrev              VARCHAR(50) NOT NULL,
 has_attribute_collections    NUMERIC(1),
 is_many_to_one_with_parent   NUMERIC(1),
 modification_date            DATE NOT NULL,
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
 FOREIGN KEY (study_id) REFERENCES :SCHEMA_PREFIX.study,
 FOREIGN KEY (parent_id) REFERENCES :SCHEMA_PREFIX.entitytype,
 FOREIGN KEY (entity_type_id) REFERENCES :SCHEMA_PREFIX.entitytype,
 PRIMARY KEY (entity_type_graph_id)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON :SCHEMA_PREFIX.EntityTypeGraph TO gus_w;
GRANT SELECT ON :SCHEMA_PREFIX.EntityTypeGraph TO gus_r;

CREATE SEQUENCE :SCHEMA_PREFIX.EntityTypeGraph_sq;
GRANT SELECT ON :SCHEMA_PREFIX.EntityTypeGraph_sq TO gus_w;
GRANT SELECT ON :SCHEMA_PREFIX.EntityTypeGraph_sq TO gus_r;

CREATE INDEX entitytypegraph_ix_1 ON :SCHEMA_PREFIX.entitytypegraph (study_id, entity_type_id, parent_id, entity_type_graph_id) TABLESPACE indx;
CREATE INDEX entitytypegraph_ix_2 ON :SCHEMA_PREFIX.entitytypegraph (parent_id, entity_type_graph_id) TABLESPACE indx;
CREATE INDEX entitytypegraph_ix_3 ON :SCHEMA_PREFIX.entitytypegraph (entity_type_id, entity_type_graph_id) TABLESPACE indx;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'EntityTypeGraph',
       'Standard', 'entity_type_graph_id',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM 
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = lower(':SCHEMA_PREFIX')) d
WHERE 'entitytypegraph' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);


-----------------------------------------------------------

CREATE TABLE :SCHEMA_PREFIX.AttributeUnit (
 attribute_unit_id                NUMERIC(12) NOT NULL,
 entity_type_id                      NUMERIC(12) NOT NULL,
 attr_ontology_term_id               NUMERIC(10) NOT NULL,
 unit_ontology_term_id               NUMERIC(10) NOT NULL,
 modification_date            DATE NOT NULL,
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
 FOREIGN KEY (entity_type_id) REFERENCES :SCHEMA_PREFIX.EntityType,
 FOREIGN KEY (attr_ontology_term_id) REFERENCES sres.ontologyterm,
 FOREIGN KEY (unit_ontology_term_id) REFERENCES sres.ontologyterm,
 PRIMARY KEY (attribute_unit_id)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON :SCHEMA_PREFIX.AttributeUnit TO gus_w;
GRANT SELECT ON :SCHEMA_PREFIX.AttributeUnit TO gus_r;

CREATE SEQUENCE :SCHEMA_PREFIX.AttributeUnit_sq;
GRANT SELECT ON :SCHEMA_PREFIX.AttributeUnit_sq TO gus_w;
GRANT SELECT ON :SCHEMA_PREFIX.AttributeUnit_sq TO gus_r;

CREATE INDEX attributeunit_ix_1 ON :SCHEMA_PREFIX.attributeunit (entity_type_id, attr_ontology_term_id, unit_ontology_term_id, attribute_unit_id) TABLESPACE indx;
CREATE INDEX attributeunit_ix_2 ON :SCHEMA_PREFIX.attributeunit (attr_ontology_term_id, attribute_unit_id) TABLESPACE indx;
CREATE INDEX attributeunit_ix_3 ON :SCHEMA_PREFIX.attributeunit (unit_ontology_term_id, attribute_unit_id) TABLESPACE indx;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'AttributeUnit',
       'Standard', 'attribute_unit_id',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM 
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = lower(':SCHEMA_PREFIX')) d
WHERE 'attributeunit' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

-----------------------------------------------------------


CREATE TABLE :SCHEMA_PREFIX.ProcessTypeComponent (
 process_type_component_id       NUMERIC(12) NOT NULL,
 process_type_id                 NUMERIC(12) NOT NULL,
 component_id                 NUMERIC(12) NOT NULL,
 order_num                    NUMERIC(2) NOT NULL,
 modification_date            DATE NOT NULL,
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
 FOREIGN KEY (process_type_id) REFERENCES :SCHEMA_PREFIX.ProcessType,
 FOREIGN KEY (component_id) REFERENCES :SCHEMA_PREFIX.ProcessType,
 PRIMARY KEY (process_type_component_id)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON :SCHEMA_PREFIX.ProcessTypeComponent TO gus_w;
GRANT SELECT ON :SCHEMA_PREFIX.ProcessTypeComponent TO gus_r;

CREATE SEQUENCE :SCHEMA_PREFIX.ProcessTypeComponent_sq;
GRANT SELECT ON :SCHEMA_PREFIX.ProcessTypeComponent_sq TO gus_w;
GRANT SELECT ON :SCHEMA_PREFIX.ProcessTypeComponent_sq TO gus_r;

CREATE INDEX ptc_ix_1 ON :SCHEMA_PREFIX.processtypecomponent (process_type_id, component_id, order_num, process_type_component_id) TABLESPACE indx;
CREATE INDEX ptc_ix_2 ON :SCHEMA_PREFIX.processtypecomponent (component_id, process_type_component_id) TABLESPACE indx;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'ProcessTypeComponent',
       'Standard', 'process_type_component_id',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM 
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = lower(':SCHEMA_PREFIX')) d
WHERE 'processtypecomponent' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);


-----------------------------------------------------------

CREATE TABLE :SCHEMA_PREFIX.AttributeValue (
 attribute_value_id           NUMERIC(12) NOT NULL,
 entity_attributes_id         NUMERIC(12) NOT NULL,
 entity_type_id               NUMERIC(12) NOT NULL,
 incoming_process_type_id        NUMERIC(12),
 attribute_stable_id                VARCHAR(255)  NOT NULL, 
 string_value                 VARCHAR(1000),
 number_value                 NUMERIC,
 date_value                   DATE, 
 modification_date            DATE NOT NULL,
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
 FOREIGN KEY (entity_attributes_id) REFERENCES :SCHEMA_PREFIX.EntityAttributes,
 FOREIGN KEY (entity_type_id) REFERENCES :SCHEMA_PREFIX.EntityType,
 FOREIGN KEY (incoming_process_type_id) REFERENCES :SCHEMA_PREFIX.ProcessType,
 PRIMARY KEY (attribute_value_id)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON :SCHEMA_PREFIX.AttributeValue TO gus_w;
GRANT SELECT ON :SCHEMA_PREFIX.AttributeValue TO gus_r;

CREATE SEQUENCE :SCHEMA_PREFIX.AttributeValue_sq;
GRANT SELECT ON :SCHEMA_PREFIX.AttributeValue_sq TO gus_w;
GRANT SELECT ON :SCHEMA_PREFIX.AttributeValue_sq TO gus_r;

CREATE INDEX attributevalue_ix_1
  ON :SCHEMA_PREFIX.attributevalue (entity_type_id, incoming_process_type_id, attribute_stable_id,
                        entity_attributes_id)
  TABLESPACE indx;

CREATE INDEX attributevalue_ix_2
  ON :SCHEMA_PREFIX.attributevalue 
     (number_value, date_value, attribute_stable_id, entity_type_id, string_value)
  TABLESPACE indx;

CREATE INDEX attributevalue_ix_3
  ON :SCHEMA_PREFIX.attributevalue 
     (attribute_stable_id, string_value, entity_type_id, number_value, date_value)
  TABLESPACE indx;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'AttributeValue',
       'Standard', 'attribute_value_id',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM 
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = lower(':SCHEMA_PREFIX')) d
WHERE 'attributevalue' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

-----------------------------------------------------------

CREATE TABLE :SCHEMA_PREFIX.Attribute (
    attribute_id                  NUMERIC(12) NOT NULL,
    entity_type_id                NUMERIC(12) not null,
    entity_type_stable_id         VARCHAR(255),
    process_type_id                 NUMERIC(12),
    ontology_term_id         NUMERIC(10),
    parent_ontology_term_id         NUMERIC(10) NOT NULL,
    stable_id VARCHAR(255) NOT NULL,
    display_name                  varchar(1500) not null,
    data_type                    VARCHAR(10) not null,
    distinct_values_count            integer,
    is_multi_valued                NUMERIC(1),
    data_shape                     VARCHAR(30),
    unit                          VARCHAR(30),
    unit_ontology_term_id         NUMERIC(10),
    precision                     integer,
    ordered_values                TEXT,
    range_min                     VARCHAR(16),
    range_max                     VARCHAR(16),
    bin_width                    VARCHAR(16),
    mean                          VARCHAR(16),
    median                        VARCHAR(16),
    lower_quartile               VARCHAR(16),
    upper_quartile               VARCHAR(16),
    modification_date            DATE NOT NULL,
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
    FOREIGN KEY (entity_type_id) REFERENCES :SCHEMA_PREFIX.EntityType,
    FOREIGN KEY (process_type_id) REFERENCES :SCHEMA_PREFIX.ProcessType,
    FOREIGN KEY (ontology_term_id) REFERENCES sres.ontologyterm,
    FOREIGN KEY (parent_ontology_term_id) REFERENCES sres.ontologyterm,
    FOREIGN KEY (unit_ontology_term_id) REFERENCES sres.ontologyterm,
    PRIMARY KEY (attribute_id)

    );
-- TODO Add back the is json constraint
--,   CONSTRAINT ensure_ov_json CHECK (ordered_values is json)

GRANT INSERT, SELECT, UPDATE, DELETE ON :SCHEMA_PREFIX.Attribute TO gus_w;
GRANT SELECT ON :SCHEMA_PREFIX.Attribute TO gus_r;

CREATE SEQUENCE :SCHEMA_PREFIX.Attribute_sq;
GRANT SELECT ON :SCHEMA_PREFIX.Attribute_sq TO gus_w;
GRANT SELECT ON :SCHEMA_PREFIX.Attribute_sq TO gus_r;

CREATE INDEX attribute_ix_1 ON :SCHEMA_PREFIX.attribute (entity_type_id, process_type_id, parent_ontology_term_id, stable_id, attribute_id) TABLESPACE indx;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'Attribute',
       'Standard', 'attribute_id',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM 
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = lower(':SCHEMA_PREFIX')) d
WHERE 'attribute' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);



-----------------------------------------------------------

CREATE TABLE :SCHEMA_PREFIX.AttributeGraph (
  attribute_graph_id                  NUMERIC(12) NOT NULL,
  study_id            NUMERIC(12) NOT NULL,
  ontology_term_id         NUMERIC(10),
  stable_id                VARCHAR(255) NOT NULL,
  parent_stable_id              VARCHAR(255) NOT NULL,
  parent_ontology_term_id       NUMERIC(10) NOT NULL,
  provider_label                varchar(3200),
  display_name                  varchar(1500) not null,
  display_order                NUMERIC(3),
  definition                   VARCHAR(4000),
  display_type                    VARCHAR(20),
  hidden                   VARCHAR(64),
  display_range_min            VARCHAR(16),
  display_range_max            VARCHAR(16),
  is_merge_key                 NUMERIC(1),
  impute_zero                  NUMERIC(1),
  is_repeated                  NUMERIC(1),
  bin_width_override           VARCHAR(16),
  -- is_hidden                    NUMERIC(1),
  is_temporal                  NUMERIC(1),
  is_featured                  NUMERIC(1),
  ordinal_values               TEXT,
  modification_date            DATE NOT NULL,
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
  FOREIGN KEY (ontology_term_id) REFERENCES sres.ontologyterm,
  FOREIGN KEY (parent_ontology_term_id) REFERENCES sres.ontologyterm,
  FOREIGN KEY (study_id) REFERENCES :SCHEMA_PREFIX.study,
  PRIMARY KEY (attribute_graph_id)

);
-- TODO Add back the is json constraint
-- ,   CONSTRAINT ensure_ordv_json CHECK (ordinal_values is json)

GRANT INSERT, SELECT, UPDATE, DELETE ON :SCHEMA_PREFIX.AttributeGraph TO gus_w;
GRANT SELECT ON :SCHEMA_PREFIX.AttributeGraph TO gus_r;

CREATE SEQUENCE :SCHEMA_PREFIX.AttributeGraph_sq;
GRANT SELECT ON :SCHEMA_PREFIX.AttributeGraph_sq TO gus_w;
GRANT SELECT ON :SCHEMA_PREFIX.AttributeGraph_sq TO gus_r;

CREATE INDEX attributegraph_ix_1 ON :SCHEMA_PREFIX.attributegraph (study_id, ontology_term_id, parent_ontology_term_id, attribute_graph_id) TABLESPACE indx;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'AttributeGraph',
       'Standard', 'attribute_graph_id',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM 
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = lower(':SCHEMA_PREFIX')) d
WHERE 'attributegraph' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);


CREATE TABLE :SCHEMA_PREFIX.StudyCharacteristic (
  study_characteristic_id      NUMERIC(5) NOT NULL,
  study_id                     NUMERIC(12) NOT NULL,
  attribute_id                 NUMERIC(12) NOT NULL,
  value_ontology_term_id       NUMERIC(10),
  value                        VARCHAR(200) NOT NULL,
  modification_date            DATE NOT NULL,
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
  FOREIGN KEY (value_ontology_term_id) REFERENCES sres.ontologyterm,
  FOREIGN KEY (attribute_id) REFERENCES sres.ontologyterm,
  FOREIGN KEY (study_id) REFERENCES :SCHEMA_PREFIX.study,
  PRIMARY KEY (study_characteristic_id)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON :SCHEMA_PREFIX.StudyCharacteristic TO gus_w;
GRANT SELECT ON :SCHEMA_PREFIX.StudyCharacteristic TO gus_r;

CREATE SEQUENCE :SCHEMA_PREFIX.StudyCharacteristic_sq;
GRANT SELECT ON :SCHEMA_PREFIX.StudyCharacteristic_sq TO gus_w;
GRANT SELECT ON :SCHEMA_PREFIX.StudyCharacteristic_sq TO gus_r;

CREATE INDEX StudyCharacteristic_ix_1 ON :SCHEMA_PREFIX.StudyCharacteristic (study_id, attribute_id, value) TABLESPACE indx;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'StudyCharacteristic',
       'Standard', 'study_characteristic_id',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM 
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = lower(':SCHEMA_PREFIX')) d
WHERE 'study_characteristic_id' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);
