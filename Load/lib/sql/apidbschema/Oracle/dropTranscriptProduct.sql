DROP TABLE apidb.TranscriptProduct;

DROP SEQUENCE apidb.TranscriptProduct_sq;

DELETE FROM core.TableInfo
WHERE lower(name) =  'transcriptproduct'
  AND database_id IN (SELECT database_id
                      FROM core.DatabaseInfo
                      WHERE lower(name) = 'apidb');

exit;
