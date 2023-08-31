DELETE FROM core.TableInfo
WHERE database_id IN (
  SELECT database_id
  FROM core.DatabaseInfo
  WHERE name IN ('hmdb','chEBI','TestTuning','ApidbTuning','EDA','Model','ApidbUserDatasets','ApiDB')
);

DELETE FROM core.DatabaseInfo WHERE name IN ('hmdb','chEBI','TestTuning','ApidbTuning','EDA','Model','ApidbUserDatasets','ApiDB');

exit;
