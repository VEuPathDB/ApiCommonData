drop table ApiDB.NAFeatureImage;
drop sequence ApiDB.NAFeatureImage_sq;

DELETE FROM core.TableInfo
WHERE lower(name) = lower('NAFeatureImage')
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo 
                     WHERE lower(name) = 'apidb');

exit;
