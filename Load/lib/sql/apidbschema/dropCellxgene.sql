drop table ApiDB.Cellxgene;
drop sequence ApiDB.Cellxgene_sq;

DELETE FROM core.TableInfo
WHERE lower(name) = lower('Cellxgene')
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo
                     WHERE lower(name) = 'apidb');

exit;
