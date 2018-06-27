DROP  TABLE apidb.DatabaseTableMapping ;

drop sequence apidb.DatabaseTableMapping_sq;

DELETE FROM core.TableInfo
WHERE lower(name) = lower('databasetablemapping')
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo 
                     WHERE lower(name) = 'apidb');


exit;
