---------------------------------------------------------------------
prompt **** creating local geneDetail tables from component databases
---------------------------------------------------------------------

create table ApidbTuning.GeneDetailCrypto as
 ( select * from apidb.Genedetail@CRYPTO);

prompt **** count for ApidbTuning.GeneDetailCrypto

select count(*) from ApidbTuning.GeneDetailCrypto;




create table ApidbTuning.GeneDetailGiardia as
 ( select * from apidb.Genedetail@GIARDIA);

prompt **** count for ApidbTuning.GeneDetailGiardia

select count(*) from ApidbTuning.GeneDetailGiardia;





create table ApidbTuning.GeneDetailPlasmo as
 ( select * from apidb.Genedetail@PLASMO);

prompt **** count for ApidbTuning.GeneDetailPlasmo

select count(*) from ApidbTuning.GeneDetailPlasmo;




create table ApidbTuning.GeneDetailToxo as
 ( select * from apidb.Genedetail@TOXO);

prompt **** count for ApidbTuning.GeneDetailToxo

select count(*) from ApidbTuning.GeneDetailToxo;




create table ApidbTuning.GeneDetailTrich as
 ( select * from apidb.Genedetail@AMITO where project_id = 'TrichDB' );

prompt **** count for ApidbTuning.GeneDetailTrich

select count(*) from ApidbTuning.GeneDetailTrich;



create table ApidbTuning.GeneDetailTriTryp as
 ( select * from apidb.Genedetail@TRITRYP);

prompt **** count for ApidbTuning.GeneDetailTriTryp

select count(*) from ApidbTuning.GeneDetailTriTryp;


--------------------------------------------------
prompt **** creating apidb.genedetail for eupathdb
--------------------------------------------------

create table apidb.Genedetail as
(
select * from ApidbTuning.GeneDetailCrypto 
union all 
select * from ApidbTuning.GeneDetailGiardia 
union all
select * from ApidbTuning.GeneDetailPlasmo  
union all
select * from ApidbTuning.GeneDetailToxo 
union all
select * from ApidbTuning.GeneDetailTrich 
union all
select * from ApidbTuning.GeneDetailTriTryp 
);

--------------------------------------------------------------
prompt **** NOT removing genedetail tables from component databases
--------------------------------------------------------------

-- drop table ApidbTuning.GeneDetailCrypto;
-- drop table ApidbTuning.GeneDetailGiardia;
-- drop table ApidbTuning.GeneDetailPlasmo;
-- drop table ApidbTuning.GeneDetailToxo;
-- drop table ApidbTuning.GeneDetailTrich;
-- commit;

