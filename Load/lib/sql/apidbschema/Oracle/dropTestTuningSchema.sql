-- DROP USER TestTuning CASCADE;

DELETE FROM core.TableInfo
WHERE database_id IN (SELECT database_id
                      FROM core.DatabaseInfo
                      WHERE name = 'TestTuning');

DELETE FROM core.DatabaseInfo WHERE name = 'TestTuning';

exit;
