CREATE TABLE apidb.PropertyGraph (
 property_graph_id            NUMBER(12) NOT NULL,
 name                         VARCHAR2(200) NOT NULL,
 external_database_release_id number(10) NOT NULL,
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
 PRIMARY KEY (property_graph_id)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.PropertyGraph TO gus_w;
GRANT SELECT ON apidb.PropertyGraph TO gus_r;

CREATE SEQUENCE apidb.PropertyGraph_sq;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'PropertyGraph',
       'Standard', 'property_graph_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'propertygraph' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

-----------------------------------------------------------

CREATE TABLE apidb.VertexType (
 vertex_type_id            NUMBER(12) NOT NULL,
 name                      VARCHAR2(200) NOT NULL,
 type_id                   NUMBER(10),
 isa_type                     VARCHAR2(50),
 property_graph_id            NUMBER(12) NOT NULL,
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
 FOREIGN KEY (property_graph_id) REFERENCES apidb.propertygraph,
 FOREIGN KEY (type_id) REFERENCES sres.ontologyterm,
 PRIMARY KEY (vertex_type_id)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.VertexType TO gus_w;
GRANT SELECT ON apidb.VertexType TO gus_r;

CREATE SEQUENCE apidb.VertexType_sq;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'VertexType',
       'Standard', 'vertex_type_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'vertextype' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

-----------------------------------------------------------

CREATE TABLE apidb.EdgeType (
 edge_type_id            NUMBER(12) NOT NULL,
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
 PRIMARY KEY (edge_type_id)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.EdgeType TO gus_w;
GRANT SELECT ON apidb.EdgeType TO gus_r;

CREATE SEQUENCE apidb.EdgeType_sq;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'EdgeType',
       'Standard', 'edge_type_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'edgetype' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

-----------------------------------------------------------

CREATE TABLE apidb.VertexAttributes (
 vertex_attributes_id         NUMBER(12) NOT NULL,
 name                         VARCHAR2(200) NOT NULL,
 vertex_type_id                    NUMBER(12) NOT NULL,
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
 FOREIGN KEY (vertex_type_id) REFERENCES apidb.VertexType,
 PRIMARY KEY (vertex_attributes_id),
 CONSTRAINT ensure_va_json CHECK (atts is json)   
);

CREATE SEARCH INDEX apidb.va_search_idx ON apidb.vertexattributes (atts) FOR JSON;

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.VertexAttributes TO gus_w;
GRANT SELECT ON apidb.VertexAttributes TO gus_r;

CREATE SEQUENCE apidb.VertexAttributes_sq;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'VertexAttributes',
       'Standard', 'vertex_attributes_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'vertexattributes' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

-----------------------------------------------------------

CREATE TABLE apidb.EdgeAttributes (
 edge_attributes_id           NUMBER(12) NOT NULL,
 edge_type_id                NUMBER(12) NOT NULL,
 in_vertex_id                 NUMBER(12) NOT NULL,
 out_vertex_id                NUMBER(12) NOT NULL,
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
 FOREIGN KEY (in_vertex_id) REFERENCES apidb.vertexattributes,
 FOREIGN KEY (out_vertex_id) REFERENCES apidb.vertexattributes,
 FOREIGN KEY (edge_type_id) REFERENCES apidb.edgetype,
 PRIMARY KEY (edge_attributes_id),
 CONSTRAINT ensure_ea_json CHECK (atts is json)   
);

CREATE INDEX apidb.ea_in_idx ON apidb.edgeattributes (in_vertex_id, out_vertex_id) tablespace indx;
CREATE INDEX apidb.ea_out_idx ON apidb.edgeattributes (out_vertex_id, in_vertex_id) tablespace indx;

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.EdgeAttributes TO gus_w;
GRANT SELECT ON apidb.EdgeAttributes TO gus_r;

CREATE SEQUENCE apidb.EdgeAttributes_sq;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'EdgeAttributes',
       'Standard', 'edge_attributes_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'edgeattributes' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);


-----------------------------------------------------------

CREATE TABLE apidb.VertexAttributeUnit (
 vertex_attribute_unit_id            NUMBER(12) NOT NULL,
 vertex_type_id                      NUMBER(12) NOT NULL,
 attribute_id                        NUMBER(10) NOT NULL,
 unit_id                             NUMBER(10) NOT NULL,
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
 FOREIGN KEY (vertex_type_id) REFERENCES apidb.VertexType,
 FOREIGN KEY (attribute_id) REFERENCES sres.ontologyterm,
 FOREIGN KEY (unit_id) REFERENCES sres.ontologyterm,
 PRIMARY KEY (vertex_attribute_unit_id)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.VertexAttributeUnit TO gus_w;
GRANT SELECT ON apidb.VertexAttributeUnit TO gus_r;

CREATE SEQUENCE apidb.VertexAttributeUnit_sq;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'VertexAttributeUnit',
       'Standard', 'vertex_attribute_unit_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'vertexattributeunit' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

-----------------------------------------------------------

CREATE TABLE apidb.EdgeAttributeUnit (
 edge_attribute_unit_id            NUMBER(12) NOT NULL,
 edge_type_id                      NUMBER(12) NOT NULL,
 attribute_id                        NUMBER(10) NOT NULL,
 unit_id                             NUMBER(10) NOT NULL,
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
 FOREIGN KEY (edge_type_id) REFERENCES apidb.EdgeType,
 FOREIGN KEY (attribute_id) REFERENCES sres.ontologyterm,
 FOREIGN KEY (unit_id) REFERENCES sres.ontologyterm,
 PRIMARY KEY (edge_attribute_unit_id)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.EdgeAttributeUnit TO gus_w;
GRANT SELECT ON apidb.EdgeAttributeUnit TO gus_r;

CREATE SEQUENCE apidb.EdgeAttributeUnit_sq;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'EdgeAttributeUnit',
       'Standard', 'edge_attribute_unit_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'edgeattributeunit' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

-----------------------------------------------------------

CREATE TABLE apidb.EdgeTypeComponent (
 edge_type_component_id       NUMBER(12) NOT NULL,
 edge_type_id                 NUMBER(12) NOT NULL,
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
 FOREIGN KEY (edge_type_id) REFERENCES apidb.EdgeType,
 FOREIGN KEY (component_id) REFERENCES apidb.EdgeType,
 PRIMARY KEY (edge_type_component_id)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.EdgeTypeComponent TO gus_w;
GRANT SELECT ON apidb.EdgeTypeComponent TO gus_r;

CREATE SEQUENCE apidb.EdgeTypeComponent_sq;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'EdgeTypeComponent',
       'Standard', 'edge_type_component_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'edgetypecomponent' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);




exit;
