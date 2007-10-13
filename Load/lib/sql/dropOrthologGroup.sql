DROP TABLE apidb.OrthologGroupAaSequence;

DROP SEQUENCE apidb.OrthologGroupAaSequence_sq;

DELETE FROM core.TableInfo
WHERE lower(name) =  'orthologgroupaasequence'
  AND database_id IN (SELECT database_id
                      FROM core.DatabaseInfo
                      WHERE lower(name) = 'apidb');

DROP TABLE apidb.OrthologGroup;

DROP SEQUENCE apidb.OrthologGroup_sq;

DELETE FROM core.TableInfo
WHERE lower(name) =  'orthologgroup'
  AND database_id IN (SELECT database_id
                      FROM core.DatabaseInfo
                      WHERE lower(name) = 'apidb');

exit;
