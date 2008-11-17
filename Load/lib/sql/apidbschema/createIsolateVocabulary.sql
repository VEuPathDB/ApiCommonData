CREATE TABLE ApiDB.IsolateVocabulary (
 term                        varchar(50) NOT NULL,
 parent                      varchar(50),
 type                        varchar(50) NOT NULL
);

GRANT insert, select, update, delete ON ApiDB.IsolateVocabulary TO gus_w;
GRANT select ON ApiDB.IsolateVocabulary TO gus_r;


exit;
