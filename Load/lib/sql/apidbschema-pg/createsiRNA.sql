CREATE TABLE apidb.siRNA (
 gene                         character varying(50) NOT NULL,
 go_id                        character varying(50),
 go_term                      character varying(100),
 pato_id                      character varying(50),
 pato_term                    character varying(100),
 rel_time                     character varying(100),
 plo_id                       character varying(50),
 plo_term                     character varying(100),
 evid_id                      character varying(50),
 evid_desc                    character varying(200),
 species                      character varying(200),
 db_xref                      character varying(100),
 annotator                    character varying(200),
 ROW_ALG_INVOCATION_ID NUMERIC(12) NOT NULL
);

