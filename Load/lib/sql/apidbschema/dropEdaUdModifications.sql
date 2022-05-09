set CONCAT OFF;

DROP TABLE EDA_UD.StudyDataset;
DROP SEQUENCE EDA_UD.StudyDataset_sq;
DELETE FROM core.TableInfo
WHERE lower(name) =  'studydataset'
  AND database_id IN (SELECT database_id
                      FROM core.DatabaseInfo
                      WHERE lower(name) = 'eda_ud');


exit;
