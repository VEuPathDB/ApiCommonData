DROP TABLE apidb.MetadataSpecType;
DROP SEQUENCE apidb.MetadataSpecType_sq;

DELETE FROM core.TableInfo
WHERE database_id IN (SELECT database_id
                      FROM core.DatabaseInfo
                      WHERE lower(name) = 'apidb')
  AND lower(name) = 'metadataspectype';



exit
