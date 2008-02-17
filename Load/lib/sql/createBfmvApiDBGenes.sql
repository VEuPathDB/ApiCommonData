---------------------------
-- GENEs
---------------------------
prompt *****DROP MATERIALIZED VIEW apidb.GeneAttributes;
DROP MATERIALIZED VIEW apidb.GeneAttributes;

prompt *****CREATE MATERIALIZED VIEW apidb.GeneAttributes
CREATE MATERIALIZED VIEW apidb.GeneAttributes AS
(
SELECT GeneAttributes.* FROM  
apidb.GeneAttributes@CRYPTO
UNION
SELECT GeneAttributes.* FROM  
apidb.GeneAttributes@PLASMO
UNION
SELECT GeneAttributes.* FROM  
apidb.GeneAttributes@TOXO
UNION
SELECT GeneAttributes.* FROM  
apidb.GeneAttributes@AMITO
);

prompt *****select count(*) from apidb.geneattributes@CRYPTO;
select count(*) from apidb.geneattributes@CRYPTO;
prompt *****select count(*) from apidb.geneattributes@PLASMO;
select count(*) from apidb.geneattributes@PLASMO;
prompt *****select count(*) from apidb.geneattributes@TOXO;
select count(*) from apidb.geneattributes@TOXO;
prompt *****select count(*) from apidb.geneattributes@AMITO;
select count(*) from apidb.geneattributes@AMITO;
prompt *****select count(*) from apidb.geneattributes;
select count(*) from apidb.geneattributes;



