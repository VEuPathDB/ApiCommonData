DROP TABLE apidb.OrthologGroupAaSequence;

DROP SEQUENCE apidb.OrthologGroupAaSequence_sq;

DELETE FROM core.TableInfo
WHERE lower(name) =  'orthologgroupaasequence'
  AND database_id IN (SELECT database_id
                      FROM core.DatabaseInfo
                      WHERE lower(name) = 'apidb');

--------------------------------------------------------------------------------

DROP TABLE TABLE apidb.OrthomclGroupDomain;

DROP SEQUENCE apidb.OrthomclGroupDomain_sq;

DELETE FROM core.TableInfo
WHERE lower(name) =  'OrthomclGroupDomain'
  AND database_id IN (SELECT database_id
                      FROM core.DatabaseInfo
                      WHERE lower(name) = 'apidb');

--------------------------------------------------------------------------------

DROP TABLE TABLE apidb.OrthomclGroupKeyword;

DROP SEQUENCE apidb.OrthomclGroupKeyword_sq;

DELETE FROM core.TableInfo
WHERE lower(name) =  'OrthomclGroupKeyword'
  AND database_id IN (SELECT database_id
                      FROM core.DatabaseInfo
                      WHERE lower(name) = 'apidb');

--------------------------------------------------------------------------------

DROP TABLE TABLE apidb.OrthomclResource;

DROP SEQUENCE apidb.OrthomclResource_sq;

DELETE FROM core.TableInfo
WHERE lower(name) =  'OrthomclResource'
  AND database_id IN (SELECT database_id
                      FROM core.DatabaseInfo
                      WHERE lower(name) = 'apidb');

--------------------------------------------------------------------------------

DROP TABLE TABLE apidb.GroupTaxonMatrix;

DROP SEQUENCE apidb.GroupTaxonMatrix_sq;

DELETE FROM core.TableInfo
WHERE lower(name) =  'GroupTaxonMatrix'
  AND database_id IN (SELECT database_id
                      FROM core.DatabaseInfo
                      WHERE lower(name) = 'apidb');

--------------------------------------------------------------------------------

DROP TABLE TABLE apidb.OrthomclTaxon;

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


DROP INDEX dots.aasequenceimp_ind_desc;

DROP INDEX sres.dbref_ind_id2;

DROP INDEX sres.dbref_ind_rmk;

--------------------------------------------------------------------------------
exit;
