DROP VIEW dots.ArrayElementFeature;

DELETE FROM core.TableInfo
WHERE name = 'ArrayElementFeature'
  AND database_id =
      (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'dots');

exit;
