---------------------------
-- GENEs
---------------------------
prompt *****DROP MATERIALIZED VIEW apidb.GeneId
DROP MATERIALIZED VIEW apidb.GeneId;

prompt *****CREATE MATERIALIZED VIEW apidb.GeneId
CREATE MATERIALIZED VIEW apidb.GeneId AS
(
SELECT 'CryptoDB' AS project_id, GeneId.* FROM  
apidb.GeneId@CRYPTO36UGA
UNION
SELECT 'PlasmoDB' AS project_id, GeneId.* FROM  
apidb.GeneId@PLASMO54
UNION
SELECT 'ToxoDB' AS project_id, GeneId.* FROM  
apidb.GeneId@TOXO43UGA
);

prompt *****select count(*) from apidb.geneid@CRYPTO36UGA;
select count(*) from apidb.geneid@CRYPTO36UGA;
prompt *****select count(*) from apidb.geneid@PLASMO54;
select count(*) from apidb.geneid@PLASMO54;
prompt *****select count(*) from apidb.geneid@TOXO43UGA;
select count(*) from apidb.geneid@TOXO43UGA;
prompt *****select count(*) from apidb.geneid;
select count(*) from apidb.geneid;


