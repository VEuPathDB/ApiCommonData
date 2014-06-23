drop table ApiDB.Nafeaturehaploblock;
drop sequence apidb.Nafeaturehaploblock_sq;

DELETE FROM core.TableInfo
WHERE lower(name) = lower('nafeaturehaploblock')
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo
                     WHERE lower(name) = 'apidb');

exit;
 
