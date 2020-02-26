-- DROP USER apidb CASCADE;

DELETE FROM core.TableInfo
WHERE database_id IN (SELECT database_id
                      FROM core.DatabaseInfo
                      WHERE name = 'ApiDB');

DELETE FROM core.DatabaseInfo WHERE name = 'ApiDB';

exit;
