DROP USER ApiDB CASCADE;
delete from core.tableinfo where database_id in (select database_id from core.databaseinfo where name = 'ApiDB');
delete from Core.DatabaseInfo where name = 'ApiDB';

exit;
