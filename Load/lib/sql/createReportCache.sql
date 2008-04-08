CREATE TABLE apidb.GeneTable (
 source_id  VARCHAR2(50),
 project_id  VARCHAR2(50),
 table_name VARCHAR2(80),
 row_count  NUMBER(4),
 content    CLOB
);

CREATE INDEX apidb.gtab_ix
       ON apidb.GeneTable (source_id, table_name, row_count);
CREATE INDEX apidb.gtab_name_ix
       ON apidb.GeneTable (table_name, source_id, row_count);

GRANT insert, select, update, delete ON ApiDB.GeneTable TO gus_w;
GRANT select ON ApiDB.GeneTable TO gus_r;

------------------------------------------------------------------------------
exit;
