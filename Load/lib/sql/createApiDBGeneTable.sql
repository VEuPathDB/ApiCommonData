--------------------------------------------------------------
prompt **** creating genetable tables from component databases
--------------------------------------------------------------

create table apidb.GeneTableCrypto as
 ( select * from apidb.GeneTable@CRYPTO);

prompt **** count for apidb.genetablecrypto

select count(*) from apidb.genetablecrypto;

create table apidb.GeneTableGiardia as
 ( select * from apidb.GeneTable@GIARDIA);

prompt **** count for apidb.genetablegiardia

select count(*) from apidb.genetablegiardia;


create table apidb.GeneTablePlasmo as
 ( select * from apidb.GeneTable@PLASMO);

prompt **** count for apidb.genetableplasmo

select count(*) from apidb.genetableplasmo;


create table apidb.GeneTableToxo as
 ( select * from apidb.GeneTable@TOXO);

prompt **** count for apidb.genetabletoxo

select count(*) from apidb.genetabletoxo;


create table apidb.GeneTableTrich as
 ( select * from apidb.GeneTable@AMITO where project_id = 'TrichDB' );

prompt **** count for apidb.genetabletrich

select count(*) from apidb.genetabletrich;

--------------------------------------------------
prompt **** creating apidb.genetable for eupathdb
--------------------------------------------------

create table apidb.GeneTable as
(
select * from apidb.GeneTableCRYPTO 
union all 
select * from apidb.GeneTableGIARDIA 
union all
select * from apidb.GeneTablePLASMO  
union all
select * from apidb.GeneTableTOXO 
union all
select * from apidb.GeneTableTRICH 
);

--------------------------------------------------------------
prompt **** NOT removing genetable tables from component databases
--------------------------------------------------------------

-- drop table apidb.GeneTableCrypto;
-- drop table apidb.GeneTableGiardia;
-- drop table apidb.GeneTablePlasmo;
-- drop table apidb.GeneTableToxo;
-- drop table apidb.GeneTableTrich;
-- commit;

