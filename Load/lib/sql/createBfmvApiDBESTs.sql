
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


