/* making table to track locations of version 4 genes */

drop table apidb.toxoversion4genes;

copy from apidb/po34weep@toxo43p to apidb/po34weep@toxo440n -
create apidb.toxoversion4genes using -
select source_id,sequence_id,start_min,end_max,strand,context_start,context_end,product -   
from apidb.geneattributes;

grant select on apidb.toxoversion4genes to gus_r;

CREATE INDEX apidb.tver4_source_id_idx ON apidb.toxoversion4genes (source_id);

commit;

quit;
