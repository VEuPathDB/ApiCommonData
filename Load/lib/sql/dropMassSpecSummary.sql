DROP TABLE apidb.MassSpecSummary;

DROP SEQUENCE apidb.MassSpecSummary_sq;

DELETE FROM core.TableInfo
WHERE lower(name) = lower('MassSpecSummary')
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo 
                     WHERE lower(name) = 'apidb');

exit;
