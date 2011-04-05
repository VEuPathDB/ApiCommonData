DROP TABLE apidb.GeneInteraction;

DROP SEQUENCE apidb.GeneInteraction_sq;

DELETE FROM core.TableInfo
WHERE name = 'GeneInteraction'
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo
                     WHERE name = 'ApiDB');

exit;
