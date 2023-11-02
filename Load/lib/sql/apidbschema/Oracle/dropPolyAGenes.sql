DROP TABLE apidb.PolyAGenes;

DROP SEQUENCE apidb.PolyAGenes_sq;


DROP INDEX apidb.polyagenes_data_idx;

DROP INDEX index apidb.polyagenes_revfk_idx;

delete from Core.TableInfo where name = 'PolyAGenes';

exit;
