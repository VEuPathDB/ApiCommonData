create table apidb.deprecatedgenes (
SOURCE_ID                               VARCHAR2(50),
MODIFICATION_DATE                       DATE
);

GRANT insert, select, update, delete ON ApiDB.deprecatedgenes TO gus_w;
GRANT select ON ApiDB.deprecatedgenes TO gus_r;


exit;
