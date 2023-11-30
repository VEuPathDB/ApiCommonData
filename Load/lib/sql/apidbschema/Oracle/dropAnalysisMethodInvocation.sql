DROP TABLE apidb.AnalysisMethodInvocation;

DROP SEQUENCE apidb.AnalysisMethodInvocation_sq;

DELETE FROM core.TableInfo
WHERE lower(name) = lower('AnalysisMethodInvocation')
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo 
                     WHERE lower(name) = 'apidb');

exit;
