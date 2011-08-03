DROP TABLE apidb.PhylogeneticTree;

CREATE TABLE apidb.PhylogeneticTree (
   source_id varchar2(50),
   atv clob,
   con clob);

GRANT SELECT ON apidb.PhylogeneticTree TO gus_r;
GRANT INSERT, UPDATE, DELETE ON apidb.PhylogeneticTree TO gus_w;

exit
