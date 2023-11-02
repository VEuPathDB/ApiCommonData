drop table apidb.SequenceVariation;
drop sequence apidb.SequenceVariation_sq;

drop table apidb.Snp;
drop sequence apidb.Snp_sq;

DELETE FROM core.TableInfo
WHERE lower(name) = lower('snp')
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo 
                     WHERE lower(name) = 'apidb');

DELETE FROM core.TableInfo
WHERE lower(name) = lower('sequencevariation')
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo 
                     WHERE lower(name) = 'apidb');


exit
