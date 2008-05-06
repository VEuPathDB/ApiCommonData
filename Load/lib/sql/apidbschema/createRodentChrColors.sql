
CREATE TABLE ApiDB.RodentChrColors (
 chromosome  varchar(10) NOT NULL,
 color       varchar(20), 
 value	     varchar(10) 
);

GRANT insert, select, update, delete ON ApiDB.RodentChrColors TO gus_w;
GRANT select ON ApiDB.RodentChrColors TO gus_r;


exit;
