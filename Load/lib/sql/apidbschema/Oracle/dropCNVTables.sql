DROP TABLE ApiDB.ChrCopyNumber;
DROP TABLE ApiDB.GeneCopyNumber;


DROP SEQUENCE ApiDB.ChrCopyNumber_SQ;
DROP SEQUENCE ApiDB.GeneCopyNumber_SQ;

DELETE FROM core.TableInfo
WHERE lower(name) in ('chrcopynumber', 'genecopynumber')
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo
                     WHERE lower(name) = 'apidb');

exit;
