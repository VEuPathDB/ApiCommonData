DROP TABLE  ApiDBUserDatasets.UD_GeneId;

drop table ApiDBUserDatasets.UD_NaFeatureExpression;

drop  table ApiDBUserDatasets.UD_PROTOCOLAPPNODE;

drop sequence ApiDBUserDatasets.UD_ProtocolAppNode_sq;

drop sequence ApiDBUserDatasets.UD_NaFeatureExpression_sq;

DELETE FROM core.TableInfo
WHERE lower(name) = lower('UD_NaFeatureExpression')
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo 
                     WHERE lower(name) = 'ApidbUserDatasets');

DELETE FROM core.TableInfo
WHERE lower(name) = lower('UD_ProtocolAppNode')
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo 
                     WHERE lower(name) = 'ApidbUserDatasets');

exit;
