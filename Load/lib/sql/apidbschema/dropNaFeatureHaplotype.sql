DROP TABLE apidb.NAFeatureHaplotype;

DROP SEQUENCE apidb.NAFeatureHaplotype_sq;

DELETE FROM core.TableInfo
WHERE lower(name) = lower('nafeaturehaplotype')
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo 
                     WHERE lower(name) = 'apidb');

exit;
