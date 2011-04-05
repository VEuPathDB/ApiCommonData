---------------------------------------------------------------------
prompt **** creating local geneDetail tables from component databases
---------------------------------------------------------------------

create table apidb.GenedetailCrypto as
 ( select * from apidb.Genedetail@CRYPTO);

prompt **** count for apidb.genedetailcrypto

select count(*) from apidb.genedetailcrypto;




create table apidb.GenedetailGiardia as
 ( select * from apidb.Genedetail@GIARDIA);

prompt **** count for apidb.genedetailgiardia

select count(*) from apidb.genedetailgiardia;





create table apidb.GenedetailPlasmo as
 ( select * from apidb.Genedetail@PLASMO);

prompt **** count for apidb.genedetailplasmo

select count(*) from apidb.genedetailplasmo;




create table apidb.GenedetailToxo as
 ( select * from apidb.Genedetail@TOXO);

prompt **** count for apidb.genedetailtoxo

select count(*) from apidb.genedetailtoxo;




create table apidb.GenedetailTrich as
 ( select * from apidb.Genedetail@AMITO where project_id = 'TrichDB' );

prompt **** count for apidb.genedetailtrich

select count(*) from apidb.genedetailtrich;



create table apidb.GenedetailTriTryp as
 ( select * from apidb.Genedetail@TRITRYP);

prompt **** count for apidb.genedetailtritryp

select count(*) from apidb.genedetailtritryp;


--------------------------------------------------
prompt **** creating apidb.genedetail for eupathdb
--------------------------------------------------

create table apidb.Genedetail as
(
select * from apidb.GenedetailCRYPTO 
union all 
select * from apidb.GenedetailGIARDIA 
union all
select * from apidb.GenedetailPLASMO  
union all
select * from apidb.GenedetailTOXO 
union all
select * from apidb.GenedetailTRICH 
union all
select * from apidb.GenedetailTRITRYP 
);

--------------------------------------------------------------
prompt **** NOT removing genedetail tables from component databases
--------------------------------------------------------------

-- drop table apidb.GenedetailCrypto;
-- drop table apidb.GenedetailGiardia;
-- drop table apidb.GenedetailPlasmo;
-- drop table apidb.GenedetailToxo;
-- drop table apidb.GenedetailTrich;
-- commit;

