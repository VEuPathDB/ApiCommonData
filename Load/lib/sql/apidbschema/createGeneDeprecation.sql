CREATE TABLE ApiDB.GeneDeprecation (
 source_id     VARCHAR2(30) NOT NULL,
 action        VARCHAR2(30) NOT NULL,
 action_date   DATE NOT NULL,
 reason        VARCHAR2(300)
);

GRANT insert, select, update, delete ON ApiDB.GeneDeprecation TO gus_w;
GRANT select ON ApiDB.GeneDeprecation TO gus_r;
GRANT select ON ApiDB.GeneDeprecation TO gus_w;

exit;


