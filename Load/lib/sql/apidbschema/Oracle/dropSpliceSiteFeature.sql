DROP TABLE apidb.SpliceSiteFeature;
DROP SEQUENCE apidb.SpliceSiteFeature_sq;

drop index apidb.ssf_revfk_ix;

delete from Core.TableInfo where name = 'SpliceSiteFeature';

exit;

