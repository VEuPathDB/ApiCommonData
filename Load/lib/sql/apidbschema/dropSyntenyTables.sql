drop table ApiDB.SyntenicGene;
drop sequence ApiDB.SyntenicGene_sq;
delete from Core.TableInfo where name = 'SyntenicGene';

drop table ApiDB.SyntenicScale;
drop sequence ApiDB.SyntenicScale_sq;
delete from Core.TableInfo where name = 'SyntenicScale';

drop table ApiDB.Synteny;
drop sequence ApiDB.Synteny_sq;
delete from Core.TableInfo where name = 'Synteny';


exit;
