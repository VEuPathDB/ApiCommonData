drop table ApiDB.NAFeatureEpitope;
drop sequence ApiDB.NAFeatureEpitope_sq;
DELETE FROM core.TableInfo
WHERE lower(name) = lower('NAFeatureEpitope')
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo
                     WHERE lower(name) = 'apidb');


----------------------------------------------------------
drop table ApiDB.NAFeatureEpitopeAccession;
drop seqeunce ApiDB.NAFeatureEpitopeAccession_sq;
DELETE FROM core.TableInfo
WHERE lower(name) = lower('NAFeatureEpitopeAccession')
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo
                     WHERE lower(name) = 'apidb');

exit;
