DROP TABLE apidb.MetadataType;

DROP SEQUENCE apidb.MetadataType_sq;

DELETE FROM core.TableInfo
WHERE lower(name) = lower('MetadataType')
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo 
                     WHERE lower(name) = 'apidb');

exit;
