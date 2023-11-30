DROP TABLE apidb.GeneName;

DROP SEQUENCE apidb.GeneName_sq;

DELETE FROM core.TableInfo
WHERE lower(name) =  'genename'
  AND database_id IN (SELECT database_id
                      FROM core.DatabaseInfo
                      WHERE lower(name) = 'apidb');

exit;
