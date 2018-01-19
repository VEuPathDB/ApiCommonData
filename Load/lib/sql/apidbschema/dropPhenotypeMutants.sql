DROP SEQUENCE ApiDB.PhenotypeMutants_sq;

DROP TABLE ApiDB.PhenotypeMutants;

DELETE FROM core.TableInfo
WHERE lower(name) = 'phenotypemutants'
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo 
                     WHERE lower(name) = 'apidb');

exit;
