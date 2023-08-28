DROP SEQUENCE ApiDB.PhenotypeScore_sq;

DROP TABLE ApiDB.PhenotypeScore;

DELETE FROM core.TableInfo
WHERE lower(name) = 'phenotypescore'
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo 
                     WHERE lower(name) = 'apidb');

exit;
