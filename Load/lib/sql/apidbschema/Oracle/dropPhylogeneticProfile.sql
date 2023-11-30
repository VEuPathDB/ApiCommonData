DROP SEQUENCE ApiDB.PhyloProfile_sq;

DROP TABLE ApiDB.PhylogeneticProfile;

DELETE FROM core.TableInfo
WHERE lower(name) = 'phylogeneticprofile'
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo 
                     WHERE lower(name) = 'apidb');
exit;
