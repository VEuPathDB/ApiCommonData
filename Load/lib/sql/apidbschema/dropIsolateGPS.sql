drop table ApiDB.IsolateGPS;
drop sequence ApiDB.IsolateGPS_sq;

DELETE FROM core.TableInfo
WHERE lower(name) = lower('IsolateGPS')
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo 
                     WHERE lower(name) = 'apidb');

exit;
