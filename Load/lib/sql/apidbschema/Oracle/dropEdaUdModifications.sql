set CONCAT OFF;

DROP TABLE ApidbUserDatasets.DatasetAttributes;
DROP SEQUENCE ApidbUserDatasets.DatasetAttributes_sq;
DELETE FROM core.TableInfo
WHERE lower(name) =  'datasetattributes'
  AND database_id IN (SELECT database_id
                      FROM core.DatabaseInfo
                      WHERE lower(name) = 'apidbuserdatasets');


exit;
