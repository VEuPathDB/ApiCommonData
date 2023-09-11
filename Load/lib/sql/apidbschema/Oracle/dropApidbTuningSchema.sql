-- DROP USER ApidbTuning CASCADE;

DELETE FROM core.TableInfo
WHERE database_id IN (SELECT database_id
                      FROM core.DatabaseInfo
                      WHERE name = 'ApidbTuning');

DELETE FROM core.DatabaseInfo WHERE name = 'ApidbTuning';

exit;
