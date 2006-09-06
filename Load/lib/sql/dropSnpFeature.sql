DROP VIEW dots.SnpFeature;

DELETE FROM core.TableInfo
WHERE name = 'SnpFeature'
  AND database_id =
      (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'dots');

exit;
