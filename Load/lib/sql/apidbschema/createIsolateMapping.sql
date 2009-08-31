CREATE TABLE ApiDB.IsolateMapping (
 na_sequence_id              NUMBER(10) NOT NULL,
 isolate_vocabulary_id       NUMBER(10) NOT NULL,
 FOREIGN KEY (na_sequence_id) REFERENCES DoTS.NaSequenceImp (na_sequence_id),
 FOREIGN KEY (isolate_vocabulary_id) REFERENCES ApiDB.IsolateVocabulary (isolate_vocabulary_id),
);


GRANT insert, select, update, delete ON ApiDB.IsolateMapping TO gus_w;
GRANT select ON ApiDB.IsolateMapping TO gus_r;

exit;
