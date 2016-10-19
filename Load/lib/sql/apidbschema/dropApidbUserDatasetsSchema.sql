DROP USER apidbuserdatasets CASCADE;

DELETE FROM core.TableInfo
WHERE database_id IN (SELECT database_id
                      FROM core.DatabaseInfo
                      WHERE name = 'ApidbUserDatasets');

DELETE FROM core.DatabaseInfo WHERE name = 'ApidbUserDatasets';

exit;
