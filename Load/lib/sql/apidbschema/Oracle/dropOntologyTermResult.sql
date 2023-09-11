DROP TABLE apidb.OntologyTermResult;

DROP SEQUENCE apidb.OntologyTermResult_sq;

DELETE FROM core.TableInfo
WHERE lower(name) = lower('ontologytermresult')
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo 
                     WHERE lower(name) = 'apidb');

exit;
