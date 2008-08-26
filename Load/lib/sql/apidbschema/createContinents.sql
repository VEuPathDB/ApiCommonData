CREATE TABLE ApiDB.Continents (
 country    varchar(50) NOT NULL,
 continent  varchar(50) NOT NULL
);

GRANT insert, select, update, delete ON ApiDB.Continents TO gus_w;
GRANT select ON ApiDB.Continents TO gus_r;


exit;
