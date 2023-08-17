drop table ApiDB.LongReadTranscript;
--drop sequence ApiDB.LongReadTranscript_sq;

DELETE FROM core.TableInfo
WHERE lower(name) = lower('LongReadTranscript')
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo
                     WHERE lower(name) = 'apidb');

exit;
