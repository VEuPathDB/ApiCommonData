DROP TABLE ApiDB.ReactionXRefs;
DROP TABLE ApiDB.ReactionRelationship;
DROP TABLE ApiDB.Reaction;

DROP TABLE ApiDB.PathwayRelationship;
DROP TABLE ApiDB.PathwayNode;
DROP TABLE ApiDB.Pathway;


DROP SEQUENCE ApiDB.Pathway_SQ;
DROP SEQUENCE ApiDB.PathwayNode_SQ;
DROP SEQUENCE ApiDB.PathwayRelationship_SQ;
DROP SEQUENCE ApiDB.Reaction_SQ;
DROP SEQUENCE ApiDB.ReactionRelationship_SQ;
DROP SEQUENCE ApiDB.ReactionXRefs_SQ;

DELETE FROM core.TableInfo
WHERE lower(name) in ('pathway', 'pathwaynode', 'pathwayrelationship','reaction', 'reactionrelationship', 'reactionxrefs')
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo
                     WHERE lower(name) = 'apidb');

exit;
