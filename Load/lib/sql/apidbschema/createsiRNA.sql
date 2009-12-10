CREATE TABLE apidb.siRNA (
 gene                         VARCHAR2(50) NOT NULL,
 go_id                        VARCHAR2(50),
 go_term                      VARCHAR2(100),
 pato_id                      VARCHAR2(50),
 pato_term                    VARCHAR2(100),
 rel_time                     VARCHAR2(100),
 plo_id                       VARCHAR2(50),
 plo_term                     VARCHAR2(100),
 evid_id                      VARCHAR2(50),
 evid_desc                    VARCHAR2(200),
 species                      VARCHAR2(200),
 db_xref                      VARCHAR2(100),
 annotator                    VARCHAR2(200),
 ROW_ALG_INVOCATION_ID NUMBER(12) NOT NULL
);
GRANT SELECT ON apidb.siRNA TO gus_r;
GRANT SELECT ON apidb.siRNA TO gus_w;

exit;
