DROP TABLE apidb.SubjectResult;

DROP SEQUENCE apidb.SubjectResult_sq;

DELETE FROM core.TableInfo
WHERE lower(name) = lower('subjectresult')
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo 
                     WHERE lower(name) = 'apidb');

exit;
