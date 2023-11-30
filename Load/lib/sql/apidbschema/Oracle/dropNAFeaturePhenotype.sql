DROP SEQUENCE ApiDB.NAFeaturePhenotype_sq;

DROP TABLE ApiDB.NAFeaturePhenotype;

DELETE FROM core.TableInfo
WHERE lower(name) = 'nafeaturephenotype'
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo 
                     WHERE lower(name) = 'apidb');

exit;
