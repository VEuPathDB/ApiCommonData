DROP TABLE ApiDB.AlphaFold;

DROP SEQUENCE ApiDB.AlphaFold_SQ;

DELETE FROM core.TableInfo
WHERE lower(name) = 'alphafold'
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo
                     WHERE lower(name) = 'apidb');

exit;
