---------------------------
-- GENEs
---------------------------
prompt *****DROP MATERIALIZED VIEW apidb.GeneAttributes;
DROP MATERIALIZED VIEW apidb.GeneAttributes;

prompt *****CREATE MATERIALIZED VIEW apidb.GeneAttributes
CREATE MATERIALIZED VIEW apidb.GeneAttributes AS
(
SELECT GeneAttributes.* FROM  
apidb.GeneAttributes@CRDEV35A_LOQUAT
UNION
SELECT GeneAttributes.* FROM  
apidb.GeneAttributes@PLAS54P
UNION
SELECT GeneAttributes.* FROM  
apidb.GeneAttributes@TOXO43P
);

prompt *****select count(*) from apidb.geneattributes@CRDEV35A_LOQUAT;
select count(*) from apidb.geneattributes@CRDEV35A_LOQUAT;
prompt *****select count(*) from apidb.geneattributes@PLAS54P;
select count(*) from apidb.geneattributes@PLAS54P;
prompt *****select count(*) from apidb.geneattributes@TOXO43P;
select count(*) from apidb.geneattributes@TOXO43P;
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
apidb.SequenceAttributes@CRDEV35A_LOQUAT
UNION
SELECT SequenceAttributes.* FROM  
apidb.SequenceAttributes@PLAS54P
UNION
SELECT SequenceAttributes.* FROM  
apidb.SequenceAttributes@TOXO43P
);

prompt *****select count(*) from apidb.sequenceattributes@CRDEV35A_LOQUAT;
select count(*) from apidb.sequenceattributes@CRDEV35A_LOQUAT;
prompt *****select count(*) from apidb.sequenceattributes@PLAS54P;
select count(*) from apidb.sequenceattributes@PLAS54P;
prompt *****select count(*) from apidb.sequenceattributes@TOXO43P;
select count(*) from apidb.sequenceattributes@TOXO43P;
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
apidb.EstAttributes@CRDEV35A_LOQUAT
UNION
SELECT EstAttributes.* FROM  
apidb.EstAttributes@PLAS54P
UNION
SELECT EstAttributes.* FROM  
apidb.EstAttributes@TOXO43P
);

prompt *****select count(*) from apidb.estattributes@CRDEV35A_LOQUAT;
select count(*) from apidb.estattributes@CRDEV35A_LOQUAT;
prompt *****select count(*) from apidb.estattributes@PLAS54P;
select count(*) from apidb.estattributes@PLAS54P;
prompt *****select count(*) from apidb.estattributes@TOXO43P;
select count(*) from apidb.estattributes@TOXO43P;
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
apidb.OrfAttributes@CRDEV35A_LOQUAT
UNION
SELECT OrfAttributes.* FROM  
apidb.OrfAttributes@PLAS54P
UNION
SELECT OrfAttributes.* FROM  
apidb.OrfAttributes@TOXO43P
);

prompt *****select count(*) from apidb.orfattributes@CRDEV35A_LOQUAT;
select count(*) from apidb.orfattributes@CRDEV35A_LOQUAT;
prompt *****select count(*) from apidb.orfattributes@PLAS54P;
select count(*) from apidb.orfattributes@PLAS54P;
prompt *****select count(*) from apidb.orfattributes@TOXO43P;
select count(*) from apidb.orfattributes@TOXO43P;
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
apidb.SnpAttributes@PLAS54P
UNION
SELECT SnpAttributes.* FROM  
apidb.SnpAttributes@TOXO43P
);

prompt *****select count(*) from apidb.snpattributes@PLAS54P;
select count(*) from apidb.snpattributes@PLAS54P;
prompt *****select count(*) from apidb.snpattributes@TOXO43P;
select count(*) from apidb.snpattributes@TOXO43P;
prompt *****select count(*) from apidb.snpattributes;
select count(*) from apidb.snpattributes;

----------------------------

exit

