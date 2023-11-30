DROP TABLE ApiDB.ExternalResourceUrl;

DROP SEQUENCE ApiDB.ExternalResourceUrl_SQ;

DELETE FROM core.TableInfo
WHERE name = 'ExternalResourceUrl'
AND database_id =
    (SELECT database_id
     FROM core.DatabaseInfo
     WHERE name = 'ApiDB');


exit;
