DROP TABLE apidb.AttributeGraph;
DROP SEQUENCE apidb.AttributeGraph_sq;
DELETE FROM core.TableInfo
WHERE lower(name) =  'attributegraph'
  AND database_id IN (SELECT database_id
                      FROM core.DatabaseInfo
                      WHERE lower(name) = 'apidb');


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

DROP TABLE apidb.ProcessAttributes;
DROP SEQUENCE apidb.ProcessAttributes_sq;
DELETE FROM core.TableInfo
WHERE lower(name) =  'processattributes'
  AND database_id IN (SELECT database_id
                      FROM core.DatabaseInfo
                      WHERE lower(name) = 'apidb');


DROP TABLE apidb.EntityAttributes;
DROP SEQUENCE apidb.EntityAttributes_sq;
DELETE FROM core.TableInfo
WHERE lower(name) =  'entityattributes'
  AND database_id IN (SELECT database_id
                      FROM core.DatabaseInfo
                      WHERE lower(name) = 'apidb');


DROP TABLE apidb.ProcessTypeComponent;
DROP SEQUENCE apidb.ProcessTypeComponent_sq;
DELETE FROM core.TableInfo
WHERE lower(name) =  'processtypecomponent'
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



DROP TABLE apidb.ProcessType;
DROP SEQUENCE apidb.ProcessType_sq;
DELETE FROM core.TableInfo
WHERE lower(name) =  'processtype'
  AND database_id IN (SELECT database_id
                      FROM core.DatabaseInfo
                      WHERE lower(name) = 'apidb');


DROP TABLE apidb.EntityType;
DROP SEQUENCE apidb.EntityType_sq;
DELETE FROM core.TableInfo
WHERE lower(name) =  'entitytype'
  AND database_id IN (SELECT database_id
                      FROM core.DatabaseInfo
                      WHERE lower(name) = 'apidb');


DROP TABLE apidb.EntityGraph;
DROP SEQUENCE apidb.EntityGraph_sq;
DELETE FROM core.TableInfo
WHERE lower(name) =  'entitygraph'
  AND database_id IN (SELECT database_id
                      FROM core.DatabaseInfo
                      WHERE lower(name) = 'apidb');




exit;
