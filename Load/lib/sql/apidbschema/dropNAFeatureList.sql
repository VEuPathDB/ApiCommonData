drop table ApiDB.NAFeatureList;
drop sequence ApiDB.NAFeatureList_sq;

DELETE FROM core.TableInfo
WHERE lower(name) = lower('NAFeatureList')
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo 
                     WHERE lower(name) = 'apidb');

exit;
