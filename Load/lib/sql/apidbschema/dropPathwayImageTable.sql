DROP TABLE ApiDB.PathwayImage;

DELETE FROM core.TableInfo
WHERE lower(name) in ('pathwayimage')
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo
                     WHERE lower(name) = 'apidb');

exit;
