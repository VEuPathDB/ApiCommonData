DROP TABLE apidb.WHOStandards;

DROP SEQUENCE apidb.WHOStandards_sq;

DELETE FROM core.TableInfo
WHERE lower(name) = lower('whostandards')
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo 
                     WHERE lower(name) = 'apidb');

exit;
