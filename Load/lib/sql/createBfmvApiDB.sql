---------------------------
-- GENEs
---------------------------
prompt *****DROP MATERIALIZED VIEW apidb.GeneAttributes;
DROP MATERIALIZED VIEW apidb.GeneAttributes;

prompt *****CREATE MATERIALIZED VIEW apidb.GeneAttributes
CREATE MATERIALIZED VIEW apidb.GeneAttributes AS
(
SELECT GeneAttributes.* FROM  
apidb.GeneAttributes@CRYPTO37
UNION
SELECT GeneAttributes.* FROM  
apidb.GeneAttributes@PLASMO541
UNION
SELECT GeneAttributes.* FROM  
apidb.GeneAttributes@TOXO43UGA
UNION
SELECT GeneAttributes.* FROM  
apidb.GeneAttributes@AMITO10
);

prompt *****select count(*) from apidb.geneattributes@CRYPTO37;
select count(*) from apidb.geneattributes@CRYPTO37;
prompt *****select count(*) from apidb.geneattributes@PLASMO541;
select count(*) from apidb.geneattributes@PLASMO541;
prompt *****select count(*) from apidb.geneattributes@TOXO43UGA;
select count(*) from apidb.geneattributes@TOXO43UGA;
prompt *****select count(*) from apidb.geneattributes@AMITO10;
select count(*) from apidb.geneattributes@AMITO10;
prompt *****select count(*) from apidb.geneattributes;
select count(*) from apidb.geneattributes;

---------------------------
-- SEQUENCEs
---------------------------
prompt *****DROP MATERIALIZED VIEW apidb.SequenceAttributes;
DROP MATERIALIZED VIEW apidb.SequenceAttributes;

prompt *****CREATE MATERIALIZED VIEW apidb.SequenceAttributes
CREATE MATERIALIZED VIEW apidb.SequenceAttributes AS
(
SELECT SequenceAttributes.* FROM  
apidb.SequenceAttributes@CRYPTO37
UNION
SELECT SequenceAttributes.* FROM  
apidb.SequenceAttributes@PLASMO541
UNION
SELECT SequenceAttributes.* FROM  
apidb.SequenceAttributes@TOXO43UGA
UNION
SELECT SequenceAttributes.* FROM  
apidb.SequenceAttributes@AMITO10
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
     CAST('Theileria parva strain Muguga' as VARCHAR2(40)) as ORGANISM,
     CAST(333668 as NUMBER(10)) as NCBI_TAX_ID,
     CAST(enas.DESCRIPTION as VARCHAR2(400)) as SEQUENCE_DESCRIPTION,
     CAST(enas.SOURCE_ID as VARCHAR2(20)) as GENBANK_ACCESSION,
     CAST(null as VARCHAR2(30)) as DATABASE_VERSION,
     CAST(null as VARCHAR2(80)) as DATABASE_NAME,
     CAST(null as VARCHAR2(20)) as CHROMOSOME ,
     CAST(null as NUMBER(12)) as CHROMOSOME_ORDER_NUM
FROM dots.ExternalNASequence enas
WHERE enas.taxon_id = '88839'
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
     CAST('Theileria annulata strain Ankara' as VARCHAR2(40)) as ORGANISM,
     CAST(353154 as NUMBER(10)) as NCBI_TAX_ID,
     CAST(enas.DESCRIPTION as VARCHAR2(400)) as SEQUENCE_DESCRIPTION,
     CAST(enas.SOURCE_ID as VARCHAR2(20)) as GENBANK_ACCESSION,
     CAST(null as VARCHAR2(30)) as DATABASE_VERSION,
     CAST(null as VARCHAR2(80)) as DATABASE_NAME,
     CAST(null as VARCHAR2(20)) as CHROMOSOME ,
     CAST(null as NUMBER(12)) as CHROMOSOME_ORDER_NUM
FROM dots.ExternalNASequence enas
WHERE enas.taxon_id = '88899'
);

prompt *****select count(*) from apidb.sequenceattributes@CRYPTO37;
select count(*) from apidb.sequenceattributes@CRYPTO37;
prompt *****select count(*) from apidb.sequenceattributes@PLASMO541;
select count(*) from apidb.sequenceattributes@PLASMO541;
prompt *****select count(*) from apidb.sequenceattributes@TOXO43UGA;
select count(*) from apidb.sequenceattributes@TOXO43UGA;
prompt *****select count(*) from apidb.sequenceattributes@AMITO10;
select count(*) from apidb.sequenceattributes@AMITO10;
prompt *****select count(*) from apidb.sequenceattributes;
select count(*) from apidb.sequenceattributes;





---------------------------
-- ESTs
---------------------------

prompt *****DROP MATERIALIZED VIEW apidb.EstAttributes;
DROP MATERIALIZED VIEW apidb.EstAttributes;


prompt *****CREATE MATERIALIZED VIEW apidb.EstAttributes
CREATE MATERIALIZED VIEW apidb.EstAttributes AS
(
SELECT EstAttributes.* FROM  
apidb.EstAttributes@CRYPTO37
UNION
SELECT EstAttributes.* FROM  
apidb.EstAttributes@PLASMO541
UNION
SELECT EstAttributes.* FROM  
apidb.EstAttributes@TOXO43UGA
UNION
SELECT EstAttributes.* FROM  
apidb.EstAttributes@TOXO43UGA
UNION
SELECT EstAttributes.*, 
	CAST(null as NUMBER(5)) as LIBRARY_ID,
	CAST(null as VARCHAR2(120)) as LIBRARY_DBEST_NAME,
	CAST(null as NUMBER(10)) as ASSEMBLY_NA_SEQUENCE_ID,
	CAST(null as VARCHAR2(255)) as ASSEMBLY_SOURCE_ID,
	CAST(null as NUMBER(12)) as ASSEMBLY_EST_COUNT 
FROM  apidb.EstAttributes@AMITO10
);

prompt *****select count(*) from apidb.estattributes@CRYPTO37;
select count(*) from apidb.estattributes@CRYPTO37;
prompt *****select count(*) from apidb.estattributes@PLASMO541;
select count(*) from apidb.estattributes@PLASMO541;
prompt *****select count(*) from apidb.estattributes@TOXO43UGA;
select count(*) from apidb.estattributes@TOXO43UGA;
prompt *****select count(*) from apidb.estattributes@AMITO10;
select count(*) from apidb.estattributes@AMITO10;
prompt *****select count(*) from apidb.estattributes;
select count(*) from apidb.estattributes;





---------------------------
-- ORFs
---------------------------

prompt *****DROP MATERIALIZED VIEW apidb.OrfAttributes;
DROP MATERIALIZED VIEW apidb.OrfAttributes;


prompt *****CREATE MATERIALIZED VIEW apidb.OrfAttributes
CREATE MATERIALIZED VIEW apidb.OrfAttributes AS
(
SELECT OrfAttributes.* FROM  
apidb.OrfAttributes@CRYPTO37
UNION
SELECT OrfAttributes.* FROM  
apidb.OrfAttributes@PLASMO541
UNION
SELECT OrfAttributes.* FROM  
apidb.OrfAttributes@TOXO43UGA
UNION
SELECT OrfAttributes.* FROM  
apidb.OrfAttributes@AMITO10
);

prompt *****select count(*) from apidb.orfattributes@CRYPTO37;
select count(*) from apidb.orfattributes@CRYPTO37;
prompt *****select count(*) from apidb.orfattributes@PLASMO541;
select count(*) from apidb.orfattributes@PLASMO541;
prompt *****select count(*) from apidb.orfattributes@TOXO43UGA;
select count(*) from apidb.orfattributes@TOXO43UGA;
prompt *****select count(*) from apidb.orfattributes@AMITO10;
select count(*) from apidb.orfattributes@AMITO10;
prompt *****select count(*) from apidb.orfattributes;
select count(*) from apidb.orfattributes;





---------------------------
-- SNPs
---------------------------

prompt *****DROP MATERIALIZED VIEW apidb.SnpAttributes;
DROP MATERIALIZED VIEW apidb.SnpAttributes;


prompt *****CREATE MATERIALIZED VIEW apidb.SnpAttributes
CREATE MATERIALIZED VIEW apidb.SnpAttributes AS
(
SELECT SnpAttributes.* FROM  
apidb.SnpAttributes@CRYPTO37
UNION
SELECT SnpAttributes.* FROM  
apidb.SnpAttributes@PLASMO541
UNION
SELECT SnpAttributes.* FROM  
apidb.SnpAttributes@TOXO43UGA
UNION
SELECT SnpAttributes.* FROM  
apidb.SnpAttributes@AMITO10
);

prompt *****select count(*) from apidb.snpattributes@CRYPTO37;
select count(*) from apidb.snpattributes@CRYPTO37;
prompt *****select count(*) from apidb.snpattributes@PLASMO541;
select count(*) from apidb.snpattributes@PLASMO541;
prompt *****select count(*) from apidb.snpattributes@TOXO43UGA;
select count(*) from apidb.snpattributes@TOXO43UGA;
prompt *****select count(*) from apidb.snpattributes@AMITO10;
select count(*) from apidb.snpattributes@AMITO10;
prompt *****select count(*) from apidb.snpattributes;
select count(*) from apidb.snpattributes;

----------------------------



---------------------------
-- ISOLATES
---------------------------

prompt *****DROP MATERIALIZED VIEW apidb.IsolateAttributes;
DROP MATERIALIZED VIEW apidb.IsolateAttributes;


prompt *****CREATE MATERIALIZED VIEW apidb.IsolateAttributes
CREATE MATERIALIZED VIEW apidb.IsolateAttributes AS
(
SELECT IsolateAttributes.* FROM  
apidb.IsolateAttributes@CRYPTO37
);

prompt *****select count(*) from apidb.Isolateattributes@CRYPTO37;
select count(*) from apidb.Isolateattributes@CRYPTO37;
prompt *****select count(*) from apidb.Isolateattributes;
select count(*) from apidb.Isolateattributes;

----------------------------
