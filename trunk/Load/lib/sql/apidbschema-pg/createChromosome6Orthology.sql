Drop table if exists apidb.Chromosome6Orthology;

CREATE TABLE apidb.Chromosome6Orthology (
 group_id  character varying(20),
 source_id character varying(50),
 ROW_ALG_INVOCATION_ID NUMERIC(12) NOT NULL
);

