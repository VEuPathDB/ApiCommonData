DROP TABLE ApiDB.CompoundMassSpecResult;
DROP SEQUENCE ApiDB.CompoundMassSpecResult_SQ;

DELETE FROM core.TableInfo
WHERE lower(name) = lower('CompoundMassSpecResult')
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo 
                     WHERE lower(name) = 'apidb');
                     
DROP TABLE ApiDB.CompoundPeaksChebi;
DROP SEQUENCE ApiDB.CompoundPeaksChebi_SQ;

DELETE FROM core.TableInfo
WHERE lower(name) = lower('CompoundPeaksChebi')
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo 
                     WHERE lower(name) = 'apidb');
                              
DROP TABLE ApiDB.CompoundPeaks;
DROP SEQUENCE ApiDB.CompoundPeaks_sq;

DELETE FROM core.TableInfo
WHERE lower(name) = lower('CompoundPeaks')
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo 
                     WHERE lower(name) = 'apidb');
exit;
