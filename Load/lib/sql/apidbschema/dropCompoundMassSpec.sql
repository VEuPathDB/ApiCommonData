DROP TABLE apidb.CompoundMassSpecResult;
DROP SEQUENCE apidb.CompoundMassSpecResult_sq;

DELETE FROM core.TableInfo
WHERE lower(name) = lower('CompoundMassSpecResult')
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo 
                     WHERE lower(name) = 'apidb');
                     
DROP TABLE apidb.CompoundPeaksChebi;
DROP SEQUENCE apidb.CompoundPeaksChebi_sq;

DELETE FROM core.TableInfo
WHERE lower(name) = lower('CompoundPeaksChebi')
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo 
                     WHERE lower(name) = 'apidb');
                              
DROP TABLE apidb.CompoundPeaks;
DROP SEQUENCE apidb.CompoundPeaks_sq;

DELETE FROM core.TableInfo
WHERE lower(name) = lower('CompoundPeaks')
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo 
                     WHERE lower(name) = 'apidb');
