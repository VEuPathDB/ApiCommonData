
---------------------------
-- ESTs
---------------------------

prompt *****DROP MATERIALIZED VIEW apidb.EstAttributes;
DROP MATERIALIZED VIEW apidb.EstAttributes;


prompt *****CREATE MATERIALIZED VIEW apidb.EstAttributes
CREATE MATERIALIZED VIEW apidb.EstAttributes AS
(
SELECT EstAttributes.* FROM  
apidb.EstAttributes@CRYPTO
UNION
SELECT EstAttributes.* FROM  
apidb.EstAttributes@PLASMO
UNION
SELECT EstAttributes.* FROM  
apidb.EstAttributes@TOXO
UNION
SELECT EstAttributes.*, 
	CAST(null as NUMBER(5)) as LIBRARY_ID,
	CAST(null as VARCHAR2(120)) as LIBRARY_DBEST_NAME,
	CAST(null as NUMBER(10)) as ASSEMBLY_NA_SEQUENCE_ID,
	CAST(null as VARCHAR2(255)) as ASSEMBLY_SOURCE_ID,
	CAST(null as NUMBER(12)) as ASSEMBLY_EST_COUNT 
FROM  apidb.EstAttributes@AMITO
UNION
SELECT
     CAST('ApiDB' as VARCHAR2(47)) as PROJECT_ID,
     CAST(enas.SOURCE_ID as VARCHAR2(50)) as SOURCE_ID,
     CAST(null as NUMBER(12)) as A_COUNT,
     CAST(null as NUMBER(12)) as C_COUNT,
     CAST(null as NUMBER(12)) as G_COUNT,
     CAST(null as NUMBER(12)) as T_COUNT,
     CAST(null as NUMBER) as OTHER_COUNT,
     enas.LENGTH,
     CAST(null as VARCHAR2(6)) as AT_PERCENT,
     CAST('Other Apicomplexan (no Cmp,Pbfvy,Tg)' as VARCHAR2(40)) as ORGANISM,
     CAST(333668 as NUMBER(10)) as NCBI_TAX_ID,
     CAST(enas.DESCRIPTION as VARCHAR2(400)) as SEQUENCE_DESCRIPTION,
     CAST(enas.SOURCE_ID as VARCHAR2(20)) as GENBANK_ACCESSION,
     CAST(null as VARCHAR2(30)) as DATABASE_VERSION,
     CAST(null as VARCHAR2(80)) as DATABASE_NAME,
     CAST(null as VARCHAR2(20)) as CHROMOSOME ,
     CAST(null as NUMBER(12)) as CHROMOSOME_ORDER_NUM
FROM dots.ExternalNASequence enas
WHERE enas.taxon_id = '88165'
);

prompt *****select count(*) from apidb.estattributes@CRYPTO;
select count(*) from apidb.estattributes@CRYPTO;
prompt *****select count(*) from apidb.estattributes@PLASMO;
select count(*) from apidb.estattributes@PLASMO;
prompt *****select count(*) from apidb.estattributes@TOXO;
select count(*) from apidb.estattributes@TOXO;
prompt *****select count(*) from apidb.estattributes@AMITO;
select count(*) from apidb.estattributes@AMITO;
prompt *****select count(*) from apidb.estattributes;
select count(*) from apidb.estattributes;


