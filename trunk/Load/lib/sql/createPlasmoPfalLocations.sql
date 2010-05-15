CREATE TABLE ApiDB.PlasmoPfalLocations (
 seq_source_id       VARCHAR2(10)  NOT NULL,
 old_location        NUMBER(10)    NOT NULL,
 new_location        NUMBER(10)    NOT NULL
);

GRANT insert, select, update, delete ON ApiDB.PlasmoPfalLocations TO gus_w;
GRANT select ON ApiDB.PlasmoPfalLocations TO gus_r;
