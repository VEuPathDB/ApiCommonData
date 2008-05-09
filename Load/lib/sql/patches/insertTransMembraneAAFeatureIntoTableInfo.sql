DELETE FROM core.TableInfo
WHERE name IN 'TransMembraneAAFeature'
  AND database_id IN (SELECT database_id
                      FROM core.DatabaseInfo
                      WHERE name = 'DoTS');

DELETE FROM core.TableInfo
WHERE name = 'TransMembraneAAFeatureVer'
  AND database_id IN (SELECT database_id
                      FROM core.DatabaseInfo
                      WHERE name = 'DoTSVer');

INSERT INTO core.tableinfo (
  table_id,
  name,
  table_type,
  primary_key_column,
  database_id,
  is_versioned,
  is_view,
  view_on_table_id,
  superclass_table_id,
  is_updatable,
  modification_date,
  user_read,
  user_write,
  group_read,
  group_write,
  other_read,
  other_write,
  row_user_id,
  row_group_id,
  row_project_id,
  row_alg_invocation_id
)
SELECT
   core.tableinfo_sq.nextval,
  'TransMembraneAAFeature',
  'Standard',
  'AA_Feature_ID', --primary_key_column
  d.database_id, --database_id
  1,
  1,
  viewtable.table_id, --view_on_table_id
  supertable.table_id, --superclass_table_id
  1,
  SYSDATE,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1
FROM 
  dual,
  (SELECT database_id from core.databaseinfo where name = 'DoTS') d,
  (select table_id from core.tableinfo where name = 'AAFeatureImp') viewtable,
  (select table_id from core.tableinfo where name = 'AAFeature') supertable;




INSERT INTO core.tableinfo (
  table_id,
  name,
  table_type,
  primary_key_column,
  database_id,
  is_versioned,
  is_view,
  view_on_table_id,
  superclass_table_id,
  is_updatable,
  modification_date,
  user_read,
  user_write,
  group_read,
  group_write,
  other_read,
  other_write,
  row_user_id,
  row_group_id,
  row_project_id,
  row_alg_invocation_id
)
SELECT
   core.tableinfo_sq.nextval,
  'TransMembraneAAFeatureVer',
  'Version',
  'AA_Feature_ID', --primary_key_column
  d.database_id, --database_id
  1,
  1,
  viewtable.table_id, --view_on_table_id
  supertable.table_id, --superclass_table_id
  1,
  SYSDATE,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1
FROM 
  dual,
  (SELECT database_id from core.databaseinfo where name = 'DoTSVer') d,
  (select table_id from core.tableinfo where name = 'AAFeatureImpVer') viewtable,
  (select table_id from core.tableinfo where name = 'AAFeatureVer') supertable;

exit
