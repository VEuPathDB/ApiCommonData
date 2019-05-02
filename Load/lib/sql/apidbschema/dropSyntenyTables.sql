drop table ApiDB.Synteny;
drop sequence ApiDB.Synteny_sq;
delete from Core.TableInfo where name = 'Synteny';

drop table ApiDB.SyntenicGene;
drop sequence ApiDB.SyntenicGene_sq;
delete from Core.TableInfo where name = 'SyntenicGene';

exit;
