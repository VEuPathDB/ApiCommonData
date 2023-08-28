DROP TABLE ApiDB.EcNumberGenus;

DROP SEQUENCE ApiDB.EcNumberGenus_SQ;

DELETE FROM core.TableInfo
WHERE name = 'EcNumberGenus'
AND database_id =
    (SELECT database_id
     FROM core.DatabaseInfo
     WHERE name = 'ApiDB');


exit;
