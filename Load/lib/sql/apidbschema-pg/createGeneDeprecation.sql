CREATE TABLE ApiDB.GeneDeprecation (
 source_id     character varying(30) NOT NULL,
 action        character varying(30) NOT NULL,
 action_date   timestamp NOT NULL,
 reason        character varying(300)
);

GRANT insert, select, update, delete ON ApiDB.GeneDeprecation TO gus_w;
GRANT select ON ApiDB.GeneDeprecation TO gus_r;
GRANT select ON ApiDB.GeneDeprecation TO gus_w;



