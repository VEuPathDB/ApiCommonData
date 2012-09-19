DROP TABLE ApiDB.PathwayRelationship;
DROP TABLE ApiDB.PathwayNode;
DROP TABLE ApiDB.Pathway;


DROP SEQUENCE ApiDB.Pathway_SQ;
DROP SEQUENCE ApiDB.PathwayNode_SQ;
DROP SEQUENCE ApiDB.PathwayRelationship_SQ;

DELETE FROM core.TableInfo
WHERE lower(name) in ('pathway', 'pathwaynode', 'pathwayrelationship')
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo
                     WHERE lower(name) = 'apidb');

exit;
