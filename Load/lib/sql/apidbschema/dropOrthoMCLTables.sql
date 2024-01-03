drop table ApiDB.OrthoGroups;
drop sequence ApiDB.OrthoGroups_sq;

DELETE FROM core.TableInfo
WHERE lower(name) = lower('OrthoGroups')
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo 
                     WHERE lower(name) = 'apidb');

drop table ApiDB.OrthoGroups;
drop sequence ApiDB.OrthoGroups_sq;

DELETE FROM core.TableInfo
WHERE lower(name) = lower('OrthoGroups')
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo 
                     WHERE lower(name) = 'apidb');

drop table ApiDB.OrthoGroupCoreStats;
drop sequence ApiDB.OrthoGroupCoreStats_sq;

DELETE FROM core.TableInfo
WHERE lower(name) = lower('OrthoGroupCoreStats')
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo 
                     WHERE lower(name) = 'apidb');

drop table ApiDB.OrthoGroupCorePeripheralStats;
drop sequence ApiDB.OrthoGroupCorePeripheralStats_sq;

DELETE FROM core.TableInfo
WHERE lower(name) = lower('OrthoGroupCorePeripheralStats')
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo 
                     WHERE lower(name) = 'apidb');

drop table ApiDB.OrthoGroupResidualStats;
drop sequence ApiDB.OrthoGroupResidualStats_sq;

DELETE FROM core.TableInfo
WHERE lower(name) = lower('OrthoGroupResidualStats')
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo 
                     WHERE lower(name) = 'apidb');

exit;
