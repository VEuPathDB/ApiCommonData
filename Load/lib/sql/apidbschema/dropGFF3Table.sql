drop table ApiDB.GFF3;
drop sequence ApiDB.gff3_feature_id_idx;
delete from Core.TableInfo where name = 'GFF3';

exit;
