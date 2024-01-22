DROP TABLE apidb.OrthologGroupStats;

DROP SEQUENCE apidb.OrthologGroupStats_sq;

DELETE FROM core.TableInfo
WHERE lower(name) =  'orthologgroupstats'
  AND database_id IN (SELECT database_id
                      FROM core.DatabaseInfo
                      WHERE lower(name) = 'apidb');

--------------------------------------------------------------------------------

DROP TABLE apidb.OrthologGroupAASequence;

DROP SEQUENCE apidb.OrthologGroupAASequence_sq;

DELETE FROM core.TableInfo
WHERE lower(name) =  'orthologgroupaasequence'
  AND database_id IN (SELECT database_id
                      FROM core.DatabaseInfo
                      WHERE lower(name) = 'apidb');

--------------------------------------------------------------------------------

DROP TABLE apidb.OrthomclGroupDomain;

DROP SEQUENCE apidb.OrthomclGroupDomain_sq;

DELETE FROM core.TableInfo
WHERE lower(name) =  'OrthomclGroupDomain'
  AND database_id IN (SELECT database_id
                      FROM core.DatabaseInfo
                      WHERE lower(name) = 'apidb');

--------------------------------------------------------------------------------

DROP TABLE apidb.OrthomclGroupKeyword;

DROP SEQUENCE apidb.OrthomclGroupKeyword_sq;

DELETE FROM core.TableInfo
WHERE lower(name) =  'OrthomclGroupKeyword'
  AND database_id IN (SELECT database_id
                      FROM core.DatabaseInfo
                      WHERE lower(name) = 'apidb');

--------------------------------------------------------------------------------

DROP TABLE apidb.OrthomclResource;

DROP SEQUENCE apidb.OrthomclResource_sq;

DELETE FROM core.TableInfo
WHERE lower(name) =  'OrthomclResource'
  AND database_id IN (SELECT database_id
                      FROM core.DatabaseInfo
                      WHERE lower(name) = 'apidb');

--------------------------------------------------------------------------------

DROP TABLE apidb.GroupTaxonMatrix;

DROP SEQUENCE apidb.GroupTaxonMatrix_sq;

DELETE FROM core.TableInfo
WHERE lower(name) =  'GroupTaxonMatrix'
  AND database_id IN (SELECT database_id
                      FROM core.DatabaseInfo
                      WHERE lower(name) = 'apidb');

--------------------------------------------------------------------------------

DROP TABLE apidb.OrthomclTaxon;

DROP SEQUENCE apidb.OrthomclTaxon_sq;

DELETE FROM core.TableInfo
WHERE lower(name) =  'OrthomclTaxon'
  AND database_id IN (SELECT database_id
                      FROM core.DatabaseInfo
                      WHERE lower(name) = 'apidb');

--------------------------------------------------------------------------------

DROP TABLE apidb.OrthologGroup;

DROP SEQUENCE apidb.OrthologGroup_sq;

DELETE FROM core.TableInfo
WHERE lower(name) =  'orthologgroup'
  AND database_id IN (SELECT database_id
                      FROM core.DatabaseInfo
                      WHERE lower(name) = 'apidb');

--------------------------------------------------------------------------------

DROP TABLE apidb.OrthomclTaxon;

DROP SEQUENCE apidb.OrthomclTaxon_sq;

DELETE FROM core.TableInfo
WHERE lower(name) =  'ortholomcltaxon'
  AND database_id IN (SELECT database_id
                      FROM core.DatabaseInfo
                      WHERE lower(name) = 'apidb');

--------------------------------------------------------------------------------

DROP VIEW apidb.OrthoAASequence;

DELETE FROM core.TableInfo
WHERE lower(name) =  'orthoaasequence'
  AND database_id IN (SELECT database_id
                      FROM core.DatabaseInfo
                      WHERE lower(name) = 'apidb');

--------------------------------------------------------------------------------

exit;
