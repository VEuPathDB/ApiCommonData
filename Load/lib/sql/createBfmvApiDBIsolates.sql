---------------------------
-- ISOLATES
---------------------------

prompt *****DROP MATERIALIZED VIEW apidb.IsolateAttributes;
DROP MATERIALIZED VIEW apidb.IsolateAttributes;


prompt *****CREATE MATERIALIZED VIEW apidb.IsolateAttributes
CREATE MATERIALIZED VIEW apidb.IsolateAttributes AS
(
SELECT IsolateAttributes.* FROM  
apidb.IsolateAttributes@CRYPTO
);

prompt *****select count(*) from apidb.Isolateattributes@CRYPTO;
select count(*) from apidb.Isolateattributes@CRYPTO;
prompt *****select count(*) from apidb.Isolateattributes;
select count(*) from apidb.Isolateattributes;


