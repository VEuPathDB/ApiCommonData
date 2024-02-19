DROP TABLE ApiDB.InterproResults;

DROP SEQUENCE ApiDB.InterproResults_sq;

DELETE FROM core.TableInfo
WHERE lower(name) =  'interproresults'
  AND database_id IN (SELECT database_id
                      FROM core.DatabaseInfo
                      WHERE lower(name) = 'apidb');

exit;
