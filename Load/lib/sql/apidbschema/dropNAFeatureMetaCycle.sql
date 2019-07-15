DROP TABLE apidb.NAFeatureMetaCycle;

DROP SEQUENCE apidb.NAFeatureMetaCycle_sq;

DELETE FROM core.TableInfo
WHERE lower(name) = lower('NAFeatureMetaCycle')
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo 
                     WHERE lower(name) = 'apidb');

exit;
