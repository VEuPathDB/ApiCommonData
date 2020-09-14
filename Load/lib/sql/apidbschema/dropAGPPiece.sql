drop table ApiDB.AGPPiece;
drop sequence apidb.AGPPiece_sq;

DELETE FROM core.TableInfo
WHERE lower(name) = lower('AGPPiece')
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo 
                     WHERE lower(name) = 'apidb');

exit;
