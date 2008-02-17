
---------------------------
-- SNPs
---------------------------

prompt *****DROP MATERIALIZED VIEW apidb.SnpAttributes;
DROP MATERIALIZED VIEW apidb.SnpAttributes;


prompt *****CREATE MATERIALIZED VIEW apidb.SnpAttributes
CREATE MATERIALIZED VIEW apidb.SnpAttributes AS
(
SELECT SnpAttributes.* FROM  
apidb.SnpAttributes@CRYPTO
UNION
SELECT SnpAttributes.* FROM  
apidb.SnpAttributes@PLASMO
UNION
SELECT SnpAttributes.* FROM  
apidb.SnpAttributes@TOXO
UNION
SELECT SnpAttributes.* FROM  
apidb.SnpAttributes@AMITO
);

prompt *****select count(*) from apidb.snpattributes@CRYPTO;
select count(*) from apidb.snpattributes@CRYPTO;
prompt *****select count(*) from apidb.snpattributes@PLASMO;
select count(*) from apidb.snpattributes@PLASMO;
prompt *****select count(*) from apidb.snpattributes@TOXO;
select count(*) from apidb.snpattributes@TOXO;
prompt *****select count(*) from apidb.snpattributes@AMITO;
select count(*) from apidb.snpattributes@AMITO;
prompt *****select count(*) from apidb.snpattributes;
select count(*) from apidb.snpattributes;

