drop table ApiDB.Busco;
drop sequence ApiDB.Busco_sq;

DELETE FROM core.TableInfo
WHERE lower(name) = lower('Busco')
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo
                     WHERE lower(name) = 'apidb');

exit;
