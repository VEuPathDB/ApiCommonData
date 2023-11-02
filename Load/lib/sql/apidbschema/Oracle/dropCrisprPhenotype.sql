DROP SEQUENCE ApiDB.CrisprPhenotype_sq;

DROP TABLE ApiDB.CrisprPhenotype;

DELETE FROM core.TableInfo
WHERE lower(name) = 'crisprphenotype'
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo 
                     WHERE lower(name) = 'apidb');

exit;
