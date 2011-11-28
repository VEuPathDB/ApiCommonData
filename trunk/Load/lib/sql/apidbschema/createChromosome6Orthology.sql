CREATE TABLE apidb.Chromosome6Orthology (
 group_id  varchar2(20),
 source_id varchar2(50),
 ROW_ALG_INVOCATION_ID NUMBER(12) NOT NULL
);


GRANT insert, select, update, delete ON ApiDB.Chromosome6Orthology TO gus_w;
GRANT select ON ApiDB.Chromosome6Orthology TO gus_r;

exit;
