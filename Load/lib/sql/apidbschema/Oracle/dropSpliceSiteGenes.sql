DROP TABLE apidb.SpliceSiteGenes;
DROP SEQUENCE apidb.splicesitegenes_sq;


DROP INDEX apidb.splicesitegenes_data_idx;

delete from Core.TableInfo where name = 'SpliceSiteGenes';

exit;

