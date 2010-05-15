DROP TABLE apidb.AnalysisMethod;

DROP SEQUENCE apidb.AnalysisMethod_sq;

DELETE FROM core.TableInfo
WHERE lower(name) = lower('AnalysisMethod')
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo 
                     WHERE lower(name) = 'apidb');

exit;
