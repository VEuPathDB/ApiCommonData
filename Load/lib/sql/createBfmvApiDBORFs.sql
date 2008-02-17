
---------------------------
-- ORFs
---------------------------

prompt *****DROP MATERIALIZED VIEW apidb.OrfAttributes;
DROP MATERIALIZED VIEW apidb.OrfAttributes;


prompt *****CREATE MATERIALIZED VIEW apidb.OrfAttributes
CREATE MATERIALIZED VIEW apidb.OrfAttributes AS
(
SELECT OrfAttributes.* FROM  
apidb.OrfAttributes@CRYPTO
UNION
SELECT OrfAttributes.* FROM  
apidb.OrfAttributes@PLASMO
UNION
SELECT OrfAttributes.* FROM  
apidb.OrfAttributes@TOXO
UNION
SELECT OrfAttributes.* FROM  
apidb.OrfAttributes@AMITO
);

prompt *****select count(*) from apidb.orfattributes@CRYPTO;
select count(*) from apidb.orfattributes@CRYPTO;
prompt *****select count(*) from apidb.orfattributes@PLASMO;
select count(*) from apidb.orfattributes@PLASMO;
prompt *****select count(*) from apidb.orfattributes@TOXO;
select count(*) from apidb.orfattributes@TOXO;
prompt *****select count(*) from apidb.orfattributes@AMITO;
select count(*) from apidb.orfattributes@AMITO;
prompt *****select count(*) from apidb.orfattributes;
select count(*) from apidb.orfattributes;



