DROP TABLE ApiDB.ProfileSet;

DROP SEQUENCE ApiDB.ProfileSet_sq;

DELETE FROM core.TableInfo
WHERE name = 'ProfileSet'
AND database_id =
    (SELECT database_id
     FROM core.DatabaseInfo
     WHERE name = 'ApiDB');

DROP TABLE ApiDB.Profile;
DROP sequence ApiDB.Profile_sq;


DELETE FROM core.TableInfo
WHERE name = 'Profile'
AND database_id =
    (SELECT database_id
     FROM core.DatabaseInfo
     WHERE name = 'ApiDB');

DROP TABLE ApiDB.ProfileElement;

DROP SEQUENCE apiDB.ProfileElement_sq;

DELETE FROM core.TableInfo
WHERE name = 'ProfileElement'
AND database_id =
    (SELECT database_id
     FROM core.DatabaseInfo
     WHERE name = 'ApiDB');

DROP TABLE ApiDB.ProfileElementName;

DELETE FROM core.TableInfo
WHERE name = 'ProfileElementName'
AND database_id =
    (SELECT database_id
     FROM core.DatabaseInfo
     WHERE name = 'ApiDB');

DROP TABLE ApiDB.GeneProfileCorrelation;

DROP SEQUENCE ApiDB.GeneProfileCorrelation_sq;q TO gus_w;

DELETE FROM core.TableInfo
WHERE name = 'GeneProfileCorrelation'
AND database_id =
    (SELECT database_id
     FROM core.DatabaseInfo
     WHERE name = 'ApiDB');

exit;
