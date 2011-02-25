drop table ApiDB.GFF3;
drop sequence apidb.GFF3_sq;

DELETE FROM core.TableInfo
WHERE lower(name) = lower('GFF3')
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo 
                     WHERE lower(name) = 'apidb');

exit;
