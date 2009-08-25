CREATE TABLE ApiDB.IsolateMapping (
 na_sequence_id              NUMBER(10),
 isolate_vocabulary_id       NUMBER(10),
);


GRANT insert, select, update, delete ON ApiDB.IsolateMapping TO gus_w;
GRANT select ON ApiDB.IsolateMapping TO gus_r;

exit;
