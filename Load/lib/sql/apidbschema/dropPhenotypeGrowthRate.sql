DROP SEQUENCE ApiDB.PhenotypeGrowthrate_sq;

DROP TABLE ApiDB.PhenotypeGrowthrate;

DELETE FROM core.TableInfo
WHERE lower(name) = 'phenotypegrowthrate'
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo 
                     WHERE lower(name) = 'apidb');

exit;
