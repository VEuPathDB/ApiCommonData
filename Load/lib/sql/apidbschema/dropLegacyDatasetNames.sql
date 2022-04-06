drop table ApiDB.LegacyDataset;
drop sequence ApiDB.LegacyDataset_sq;

DELETE FROM core.TableInfo
WHERE lower(name) = lower('LegacyDataset')
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo 
                     WHERE lower(name) = 'apidb');

exit;
