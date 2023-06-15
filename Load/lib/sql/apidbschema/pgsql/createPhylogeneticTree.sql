CREATE TABLE apidb.PhylogeneticTree (
   source_id varchar(50),
   atv text,
   con text);

GRANT SELECT ON apidb.PhylogeneticTree TO gus_r;
GRANT INSERT, UPDATE, DELETE ON apidb.PhylogeneticTree TO gus_w;