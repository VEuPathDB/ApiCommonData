drop table ApiDB.GeneFeatureLodScore;
drop sequence apidb.GeneFeatureLodScore_sq;

DELETE FROM core.TableInfo
WHERE lower(name) = lower('GeneFeatureLodScore')
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo
                     WHERE lower(name) = 'apidb');

exit;
 
