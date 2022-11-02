drop table ApiDB.Indel;
drop sequence ApiDB.Indel_sq;

DELETE FROM core.TableInfo
WHERE lower(name) = lower('Indel')
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo 
                     WHERE lower(name) = 'apidb');

exit;
