DROP SEQUENCE ApiDB.PhenotypeModel_sq;

DROP TABLE ApiDB.PhenotypeModel;

DELETE FROM core.TableInfo
WHERE lower(name) = 'phenotypemodel'
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo 
                     WHERE lower(name) = 'apidb');


DROP SEQUENCE ApiDB.PhenotypeResult_sq;

DROP TABLE ApiDB.PhenotypeResult;

DELETE FROM core.TableInfo
WHERE lower(name) = 'phenotyperesult'
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo 
                     WHERE lower(name) = 'apidb');

exit;
