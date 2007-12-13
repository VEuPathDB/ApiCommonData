---------------------------
-- GENEs
---------------------------
prompt *****DROP MATERIALIZED VIEW apidb.GeneAttributes;
DROP MATERIALIZED VIEW apidb.GeneAttributes;

prompt *****CREATE MATERIALIZED VIEW apidb.GeneAttributes
CREATE MATERIALIZED VIEW apidb.GeneAttributes AS
(
SELECT GeneAttributes.* FROM  
apidb.GeneAttributes@CRYPTO36UGA
UNION
SELECT GeneAttributes.* FROM  
apidb.GeneAttributes@PLASMO54
UNION
SELECT GeneAttributes.* FROM  
apidb.GeneAttributes@TOXO43UGA
);

prompt *****select count(*) from apidb.geneattributes@CRYPTO36UGA;
select count(*) from apidb.geneattributes@CRYPTO36UGA;
prompt *****select count(*) from apidb.geneattributes@PLASMO54;
select count(*) from apidb.geneattributes@PLASMO54;
prompt *****select count(*) from apidb.geneattributes@TOXO43UGA;
select count(*) from apidb.geneattributes@TOXO43UGA;
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
apidb.SequenceAttributes@CRYPTO36UGA
UNION
SELECT SequenceAttributes.* FROM  
apidb.SequenceAttributes@PLASMO54
UNION
SELECT SequenceAttributes.* FROM  
apidb.SequenceAttributes@TOXO43UGA
);

prompt *****select count(*) from apidb.sequenceattributes@CRYPTO36UGA;
select count(*) from apidb.sequenceattributes@CRYPTO36UGA;
prompt *****select count(*) from apidb.sequenceattributes@PLASMO54;
select count(*) from apidb.sequenceattributes@PLASMO54;
prompt *****select count(*) from apidb.sequenceattributes@TOXO43UGA;
select count(*) from apidb.sequenceattributes@TOXO43UGA;
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
apidb.EstAttributes@CRYPTO36UGA
UNION
SELECT EstAttributes.* FROM  
apidb.EstAttributes@PLASMO54
UNION
SELECT EstAttributes.* FROM  
apidb.EstAttributes@TOXO43UGA
);

prompt *****select count(*) from apidb.estattributes@CRYPTO36UGA;
select count(*) from apidb.estattributes@CRYPTO36UGA;
prompt *****select count(*) from apidb.estattributes@PLASMO54;
select count(*) from apidb.estattributes@PLASMO54;
prompt *****select count(*) from apidb.estattributes@TOXO43UGA;
select count(*) from apidb.estattributes@TOXO43UGA;
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
apidb.OrfAttributes@CRYPTO36UGA
UNION
SELECT OrfAttributes.* FROM  
apidb.OrfAttributes@PLASMO54
UNION
SELECT OrfAttributes.* FROM  
apidb.OrfAttributes@TOXO43UGA
);

prompt *****select count(*) from apidb.orfattributes@CRYPTO36UGA;
select count(*) from apidb.orfattributes@CRYPTO36UGA;
prompt *****select count(*) from apidb.orfattributes@PLASMO54;
select count(*) from apidb.orfattributes@PLASMO54;
prompt *****select count(*) from apidb.orfattributes@TOXO43UGA;
select count(*) from apidb.orfattributes@TOXO43UGA;
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
apidb.SnpAttributes@CRYPTO36UGA
UNION
SELECT SnpAttributes.* FROM  
apidb.SnpAttributes@PLASMO54
UNION
SELECT SnpAttributes.* FROM  
apidb.SnpAttributes@TOXO43UGA
);

prompt *****select count(*) from apidb.snpattributes@CRYPTO36UGA;
select count(*) from apidb.snpattributes@CRYPTO36UGA;
prompt *****select count(*) from apidb.snpattributes@PLASMO54;
select count(*) from apidb.snpattributes@PLASMO54;
prompt *****select count(*) from apidb.snpattributes@TOXO43UGA;
select count(*) from apidb.snpattributes@TOXO43UGA;
prompt *****select count(*) from apidb.snpattributes;
select count(*) from apidb.snpattributes;

----------------------------



