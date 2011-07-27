DROP TABLE apidb.AaSequenceAttribute;
DROP SEQUENCE apidb.AaSequenceAttribute_sq;

DELETE FROM core.TableInfo
WHERE name = 'AaSequenceAttribute'
AND database_id =
    (SELECT database_id
     FROM core.DatabaseInfo
     WHERE name = 'ApiDB');

DROP TABLE ApidbTuning.NaSequenceAttribute;
DROP SEQUENCE ApidbTuning.NaSequenceAttribute_sq;

DELETE FROM core.TableInfo
WHERE name = 'NaSequenceAttribute'
AND database_id =
    (SELECT database_id
     FROM core.DatabaseInfo
     WHERE name = 'ApiDB');

exit
