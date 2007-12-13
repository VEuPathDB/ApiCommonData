
---------------------------
-- SEQUENCEs
---------------------------
prompt *****DROP MATERIALIZED VIEW apidb.SequenceAttributes;
DROP MATERIALIZED VIEW apidb.SequenceAttributes;

prompt *****CREATE MATERIALIZED VIEW apidb.SequenceAttributes
CREATE MATERIALIZED VIEW apidb.SequenceAttributes AS
(SELECT SequenceAttributes.*
FROM apidb.SequenceAttributes@CRYPTO36UGA
UNION
SELECT SequenceAttributes.* 
FROM apidb.SequenceAttributes@PLASMO54
UNION
SELECT SequenceAttributes.* 
FROM apidb.SequenceAttributes@TOXO43UGA
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

prompt *****select count(*) from apidb.sequenceattributes@CRYPTO36UGA;
select count(*) from apidb.sequenceattributes@CRYPTO36UGA;
prompt *****select count(*) from apidb.sequenceattributes@PLASMO54;
select count(*) from apidb.sequenceattributes@PLASMO54;
prompt *****select count(*) from apidb.sequenceattributes@TOXO43UGA;
select count(*) from apidb.sequenceattributes@TOXO43UGA;
prompt *****select count(*) from apidb.sequenceattributes;
select count(*) from apidb.sequenceattributes;
