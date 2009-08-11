CREATE TABLE ApiDB.IsolateVocabulary (
 term                        varchar(200) NOT NULL,
 parent                      varchar(200),
 type                        varchar(50) NOT NULL
);

GRANT insert, select, update, delete ON ApiDB.IsolateVocabulary TO gus_w;
GRANT select ON ApiDB.IsolateVocabulary TO gus_r;

--------------------------------------------------------------------------------


CREATE TABLE ApiDB.IsolateVocabularyLink (
 old_term                        varchar(200) NOT NULL,
 new_term                        varchar(200) NOT NULL,
 type                            varchar(50) NOT NULL
);

GRANT insert, select, update, delete ON ApiDB.IsolateVocabularyLink TO gus_w;
GRANT select ON ApiDB.IsolateVocabularyLink TO gus_r;





exit;
