DROP SEQUENCE apidb.SequenceTaxon_sq;

DROP TABLE apidb.SequenceTaxon;

DELETE FROM core.TableInfo
WHERE lower(name) = lower('SequenceTaxon')
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo 
                     WHERE lower(name) = 'apidb');

exit;
