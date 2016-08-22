DROP TABLE ApiDB.ReactionXRefs;
DROP TABLE ApiDB.ReactionRelationship;
DROP TABLE ApiDB.Reaction;


DROP SEQUENCE ApiDB.Reaction_SQ;
DROP SEQUENCE ApiDB.ReactionRelationship_SQ;
DROP SEQUENCE ApiDB.ReactionXRefs_SQ;

DELETE FROM core.TableInfo
WHERE lower(name) in ('reaction', 'reactionrelationship', 'reactionxrefs')
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo
                     WHERE lower(name) = 'apidb');

exit;
