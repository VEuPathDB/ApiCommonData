drop table ApiDB.GeneFeatureLodsScore;

DELETE FROM core.TableInfo
WHERE lower(name) = lower('GeneFeatureLodsScore')
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo
                     WHERE lower(name) = 'apidb');

exit;
 
