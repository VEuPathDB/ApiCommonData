---------------------------
-- GENEs
---------------------------
prompt *****DROP MATERIALIZED VIEW apidb.GeneId
DROP MATERIALIZED VIEW apidb.GeneId;

prompt *****CREATE MATERIALIZED VIEW apidb.GeneId
CREATE MATERIALIZED VIEW apidb.GeneId AS
(
SELECT 'cryptodb' AS project_id, GeneId.* FROM  
apidb.GeneId@CRYPTOB
UNION
SELECT 'plasmodb' AS project_id, GeneId.* FROM  
apidb.GeneId@PLASBLD
UNION
SELECT 'toxodb' AS project_id, GeneId.* FROM  
apidb.GeneId@TOXOBLD
);

prompt *****select count(*) from apidb.geneid@CRYPTOB;
select count(*) from apidb.geneid@CRYPTOB;
prompt *****select count(*) from apidb.geneid@PLASBLD;
select count(*) from apidb.geneid@PLASBLD;
prompt *****select count(*) from apidb.geneid@TOXOBLD;
select count(*) from apidb.geneid@TOXOBLD;
prompt *****select count(*) from apidb.geneid;
select count(*) from apidb.geneid;

