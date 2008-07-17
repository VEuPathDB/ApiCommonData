CREATE TABLE ApiDB.PlasmoMapp (
 na_sequence_id  NUMBER(10) NOT NULL,
 strand          NUMBER(3)  NOT NULL,
 location        NUMBER(10) NOT NULL,
 value	         FLOAT(10) NOT NULL
);

GRANT insert, select, update, delete ON ApiDB.PlasmoMapp TO gus_w;
GRANT select ON ApiDB.PlasmoMapp  TO gus_r;

CREATE INDEX apidb.plasmapp_loc_ix
ON apidb.PlasmoMapp (na_sequence_id, location);
