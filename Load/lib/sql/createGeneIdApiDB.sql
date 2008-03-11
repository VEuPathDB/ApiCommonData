---------------------------
-- GENEs
---------------------------
prompt *****DROP MATERIALIZED VIEW apidb.GeneId
DROP MATERIALIZED VIEW apidb.GeneId;

prompt *****CREATE MATERIALIZED VIEW apidb.GeneId
CREATE MATERIALIZED VIEW apidb.GeneId AS
(
SELECT 'AmitoDB' AS project_id, GeneId.* FROM  
apidb.GeneId@amito
UNION
SELECT 'CryptoDB' AS project_id, GeneId.* FROM  
apidb.GeneId@crypto
UNION
SELECT 'PlasmoDB' AS project_id, GeneId.* FROM  
apidb.GeneId@plasmo
UNION
SELECT 'ToxoDB' AS project_id, GeneId.* FROM  
apidb.GeneId@toxo
);

prompt *****select count(*) from apidb.geneid@amito;
select count(*) from apidb.geneid@amito;
prompt *****select count(*) from apidb.geneid@crypto;
select count(*) from apidb.geneid@crypto;
prompt *****select count(*) from apidb.geneid@plasmo;
select count(*) from apidb.geneid@plasmo;
prompt *****select count(*) from apidb.geneid@toxo;
select count(*) from apidb.geneid@toxo;
prompt *****select count(*) from apidb.geneid;
select count(*) from apidb.geneid;


