DROP TABLE apidb.Haplotyperesult;

DROP SEQUENCE apidb.Haplotyperesult_sq;

DELETE FROM core.TableInfo
WHERE lower(name) = lower('haplotyperesult')
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo 
                     WHERE lower(name) = 'apidb');

exit;
