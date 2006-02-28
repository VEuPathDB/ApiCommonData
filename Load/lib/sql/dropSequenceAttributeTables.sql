drop table ApiDB.AaSequenceAttribute;
drop sequence ApiDB.AaSequenceAttribute_sq;
delete from Core.TableInfo where name = 'AaSequenceAttribute';

drop table ApiDB.NaSequenceAttribute;
drop sequence ApiDB.NaSequenceAttribute_sq;
delete from Core.TableInfo where name = 'NaSequenceAttribute';

exit;
