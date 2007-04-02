---------------------------
-- GENEs
---------------------------

DROP MATERIALIZED VIEW apidb.GeneAttributes;


CREATE MATERIALIZED VIEW apidb.GeneAttributes AS
(
SELECT 'cryptodb' AS project_id, GeneAttributes.* FROM  
apidb.GeneAttributes@CRYPTOB
UNION
SELECT 'plasmodb' AS project_id, GeneAttributes.* FROM  
apidb.GeneAttributes@PLASBLD
UNION
SELECT 'toxodb' AS project_id, GeneAttributes.* FROM  
apidb.GeneAttributes@TOXOBLD
);

select count(*) from apidb.geneattributes@CRYPTOB;
select count(*) from apidb.geneattributes@PLASBLD;
select count(*) from apidb.geneattributes@TOXOBLD;
select count(*) from apidb.geneattributes;

---------------------------
-- SEQUENCEs
---------------------------

DROP MATERIALIZED VIEW apidb.SequenceAttributes;


CREATE MATERIALIZED VIEW apidb.SequenceAttributes AS
(
SELECT 'cryptodb' AS project_id, SequenceAttributes.* FROM  
apidb.SequenceAttributes@CRYPTOB
UNION
SELECT 'plasmodb' AS project_id, SequenceAttributes.* FROM  
apidb.SequenceAttributes@PLASBLD
UNION
SELECT 'toxodb' AS project_id, SequenceAttributes.* FROM  
apidb.SequenceAttributes@TOXOBLD
);

select count(*) from apidb.sequenceattributes@CRYPTOB;
select count(*) from apidb.sequenceattributes@PLASBLD;
select count(*) from apidb.sequenceattributes@TOXOBLD;
select count(*) from apidb.sequenceattributes;

---------------------------
-- ESTs
---------------------------

DROP MATERIALIZED VIEW apidb.EstAttributes;


CREATE MATERIALIZED VIEW apidb.EstAttributes AS
(
SELECT 'cryptodb' AS project_id, EstAttributes.* FROM  
apidb.EstAttributes@CRYPTOB
UNION
SELECT 'plasmodb' AS project_id, EstAttributes.* FROM  
apidb.EstAttributes@PLASBLD
UNION
SELECT 'toxodb' AS project_id, EstAttributes.* FROM  
apidb.EstAttributes@TOXOBLD
);

select count(*) from apidb.estattributes@CRYPTOB;
select count(*) from apidb.estattributes@PLASBLD;
select count(*) from apidb.estattributes@TOXOBLD;
select count(*) from apidb.estattributes;

---------------------------
-- ORFs
---------------------------

DROP MATERIALIZED VIEW apidb.OrfAttributes;


CREATE MATERIALIZED VIEW apidb.OrfAttributes AS
(
SELECT 'cryptodb' AS project_id, OrfAttributes.* FROM  
apidb.OrfAttributes@CRYPTOB
UNION
SELECT 'plasmodb' AS project_id, OrfAttributes.* FROM  
apidb.OrfAttributes@PLASBLD
UNION
SELECT 'toxodb' AS project_id, OrfAttributes.* FROM  
apidb.OrfAttributes@TOXOBLD
);

select count(*) from apidb.orfattributes@CRYPTOB;
select count(*) from apidb.orfattributes@PLASBLD;
select count(*) from apidb.orfattributes@TOXOBLD;
select count(*) from apidb.orfattributes;

---------------------------
-- SNPs
---------------------------

DROP MATERIALIZED VIEW apidb.SnpAttributes;



CREATE MATERIALIZED VIEW apidb.SnpAttributes AS
(
SELECT 'cryptodb' AS project_id, SnpAttributes.* FROM  
apidb.SnpAttributes@CRYPTOB
UNION
SELECT 'plasmodb' AS project_id, SnpAttributes.* FROM  
apidb.SnpAttributes@PLASBLD
UNION
SELECT 'toxodb' AS project_id, SnpAttributes.* FROM  
apidb.SnpAttributes@TOXOBLD
);

select count(*) from apidb.snpattributes@CRYPTOB;
select count(*) from apidb.snpattributes@PLASBLD;
select count(*) from apidb.snpattributes@TOXOBLD;
select count(*) from apidb.snpattributes;
