DROP TABLE apidb.Attribute;
DROP SEQUENCE apidb.Attribute_sq;
DELETE FROM core.TableInfo
WHERE lower(name) =  'attribute'
  AND database_id IN (SELECT database_id
                      FROM core.DatabaseInfo
                      WHERE lower(name) = 'apidb');

DROP TABLE apidb.AttributeValue;
DROP SEQUENCE apidb.AttributeValue_sq;
DELETE FROM core.TableInfo
WHERE lower(name) =  'attributevalue'
  AND database_id IN (SELECT database_id
                      FROM core.DatabaseInfo
                      WHERE lower(name) = 'apidb');

DROP TABLE apidb.EdgeAttributes;
DROP SEQUENCE apidb.EdgeAttributes_sq;
DELETE FROM core.TableInfo
WHERE lower(name) =  'edgeattributes'
  AND database_id IN (SELECT database_id
                      FROM core.DatabaseInfo
                      WHERE lower(name) = 'apidb');


DROP TABLE apidb.VertexAttributes;
DROP SEQUENCE apidb.VertexAttributes_sq;
DELETE FROM core.TableInfo
WHERE lower(name) =  'vertexattributes'
  AND database_id IN (SELECT database_id
                      FROM core.DatabaseInfo
                      WHERE lower(name) = 'apidb');


DROP TABLE apidb.EdgeTypeComponent;
DROP SEQUENCE apidb.EdgeTypeComponent_sq;
DELETE FROM core.TableInfo
WHERE lower(name) =  'edgetypecomponent'
  AND database_id IN (SELECT database_id
                      FROM core.DatabaseInfo
                      WHERE lower(name) = 'apidb');



DROP TABLE apidb.AttributeUnit;
DROP SEQUENCE apidb.AttributeUnit_sq;
DELETE FROM core.TableInfo
WHERE lower(name) =  'attributeunit'
  AND database_id IN (SELECT database_id
                      FROM core.DatabaseInfo
                      WHERE lower(name) = 'apidb');


DROP TABLE apidb.EdgeType;
DROP SEQUENCE apidb.EdgeType_sq;
DELETE FROM core.TableInfo
WHERE lower(name) =  'edgetype'
  AND database_id IN (SELECT database_id
                      FROM core.DatabaseInfo
                      WHERE lower(name) = 'apidb');


DROP TABLE apidb.VertexType;
DROP SEQUENCE apidb.VertexType_sq;
DELETE FROM core.TableInfo
WHERE lower(name) =  'vertextype'
  AND database_id IN (SELECT database_id
                      FROM core.DatabaseInfo
                      WHERE lower(name) = 'apidb');


DROP TABLE apidb.PropertyGraph;
DROP SEQUENCE apidb.PropertyGraph_sq;
DELETE FROM core.TableInfo
WHERE lower(name) =  'propertygraph'
  AND database_id IN (SELECT database_id
                      FROM core.DatabaseInfo
                      WHERE lower(name) = 'apidb');




exit;
