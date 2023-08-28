DROP TABLE apidb.SeqEdit;

DROP SEQUENCE apidb.SeqEdit_sq

DELETE FROM core.TableInfo
WHERE lower(name) = lower('seqedit')
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo 
                     WHERE lower(name) = 'apidb');

exit;
