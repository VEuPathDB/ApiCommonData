DROP TABLE ApiDB.NetworkRelContextLink;
DROP TABLE ApiDB.NetworkRelContext;
DROP TABLE ApiDB.NetworkRelationshipType;
DROP TABLE ApiDB.NetworkRelationship;
DROP TABLE ApiDB.NetworkNode;
DROP TABLE ApiDB.Network;
DROP TABLE ApiDB.NetworkContext;

DROP SEQUENCE ApiDB.NetworkContext_sq;
DROP SEQUENCE ApiDB.Network_sq;
DROP SEQUENCE ApiDB.NetworkNode_sq;
DROP SEQUENCE ApiDB.NetworkRelationship_sq;
DROP SEQUENCE ApiDB.NetworkRelationshipType_sq;
DROP SEQUENCE ApiDB.NetworkRelContext_sq;
DROP SEQUENCE ApiDB.NetworkRelContextLink_sq; 


DELETE FROM core.TableInfo
WHERE lower(name) in ('networkcontext','network','networknode','networkrelationship','networkrelationshiptype','networkrelcontext','networkrelcontextlink')
AND database_id =
    (SELECT database_id
     FROM core.DatabaseInfo
     WHERE name = 'ApiDB');

exit;
