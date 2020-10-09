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




DROP TABLE apidb.EdgeLabel;
DROP SEQUENCE apidb.EdgeLabel_sq;
DELETE FROM core.TableInfo
WHERE lower(name) =  'edgelabel'
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
