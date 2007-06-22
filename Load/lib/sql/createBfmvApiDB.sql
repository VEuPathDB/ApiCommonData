---------------------------
-- GENEs
---------------------------
prompt *****DROP MATERIALIZED VIEW apidb.GeneAttributes;
DROP MATERIALIZED VIEW apidb.GeneAttributes;

prompt *****CREATE MATERIALIZED VIEW apidb.GeneAttributes
CREATE MATERIALIZED VIEW apidb.GeneAttributes AS
(
SELECT 'cryptodb' AS project_id, GeneAttributes.* FROM  
apidb.GeneAttributes@CRYPTOB
UNION
SELECT 'plasmodb' AS project_id, GeneAttributes.* FROM  
apidb.GeneAttributes@PLASMO53
UNION
SELECT 'toxodb' AS project_id, GeneAttributes.* FROM  
apidb.GeneAttributes@TOXO42
);

prompt *****select count(*) from apidb.geneattributes@CRYPTOB;
select count(*) from apidb.geneattributes@CRYPTOB;
prompt *****select count(*) from apidb.geneattributes@PLASMO53;
select count(*) from apidb.geneattributes@PLASMO53;
prompt *****select count(*) from apidb.geneattributes@TOXO42;
select count(*) from apidb.geneattributes@TOXO42;
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
SELECT 'cryptodb' AS project_id, SequenceAttributes.* FROM  
apidb.SequenceAttributes@CRYPTOB
UNION
SELECT 'plasmodb' AS project_id, SequenceAttributes.* FROM  
apidb.SequenceAttributes@PLASMO53
UNION
SELECT 'toxodb' AS project_id, SequenceAttributes.* FROM  
apidb.SequenceAttributes@TOXO42
);

prompt *****select count(*) from apidb.sequenceattributes@CRYPTOB;
select count(*) from apidb.sequenceattributes@CRYPTOB;
prompt *****select count(*) from apidb.sequenceattributes@PLASMO53;
select count(*) from apidb.sequenceattributes@PLASMO53;
prompt *****select count(*) from apidb.sequenceattributes@TOXO42;
select count(*) from apidb.sequenceattributes@TOXO42;
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
SELECT 'cryptodb' AS project_id, EstAttributes.* FROM  
apidb.EstAttributes@CRYPTOB
UNION
SELECT 'plasmodb' AS project_id, EstAttributes.* FROM  
apidb.EstAttributes@PLASMO53
UNION
SELECT 'toxodb' AS project_id, EstAttributes.* FROM  
apidb.EstAttributes@TOXO42
);

prompt *****select count(*) from apidb.estattributes@CRYPTOB;
select count(*) from apidb.estattributes@CRYPTOB;
prompt *****select count(*) from apidb.estattributes@PLASMO53;
select count(*) from apidb.estattributes@PLASMO53;
prompt *****select count(*) from apidb.estattributes@TOXO42;
select count(*) from apidb.estattributes@TOXO42;
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
SELECT 'cryptodb' AS project_id, OrfAttributes.* FROM  
apidb.OrfAttributes@CRYPTOB
UNION
SELECT 'plasmodb' AS project_id, OrfAttributes.* FROM  
apidb.OrfAttributes@PLASMO53
UNION
SELECT 'toxodb' AS project_id, OrfAttributes.* FROM  
apidb.OrfAttributes@TOXO42
);

prompt *****select count(*) from apidb.orfattributes@CRYPTOB;
select count(*) from apidb.orfattributes@CRYPTOB;
prompt *****select count(*) from apidb.orfattributes@PLASMO53;
select count(*) from apidb.orfattributes@PLASMO53;
prompt *****select count(*) from apidb.orfattributes@TOXO42;
select count(*) from apidb.orfattributes@TOXO42;
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
SELECT 'plasmodb' AS project_id, SnpAttributes.* FROM  
apidb.SnpAttributes@PLASMO53
UNION
SELECT 'toxodb' AS project_id, SnpAttributes.* FROM  
apidb.SnpAttributes@TOXO42
);

prompt *****select count(*) from apidb.snpattributes@PLASMO53;
select count(*) from apidb.snpattributes@PLASMO53;
prompt *****select count(*) from apidb.snpattributes@TOXO42;
select count(*) from apidb.snpattributes@TOXO42;
prompt *****select count(*) from apidb.snpattributes;
select count(*) from apidb.snpattributes;

----------------------------

exit

