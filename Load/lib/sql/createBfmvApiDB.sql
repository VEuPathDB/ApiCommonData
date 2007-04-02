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

