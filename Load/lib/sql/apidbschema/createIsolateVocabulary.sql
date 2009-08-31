CREATE TABLE ApiDB.IsolateVocabulary (
 isolate_vocabulary_id       NUMBER(10),
 term                        varchar(200) NOT NULL,
 parent                      varchar(200),
 type                        varchar(50) NOT NULL,
 PRIMARY KEY (isolate_vocabulary_id)
);

CREATE SEQUENCE ApiDB.IsolateVocabulary_sq;


GRANT insert, select, update, delete ON ApiDB.IsolateVocabulary TO gus_w;
GRANT select ON ApiDB.IsolateVocabulary TO gus_r;
GRANT select ON ApiDB.IsolateVocabulary_sq TO gus_w;


------------------------------------------------------------------------------

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'IsolateVocabulary',
       'Standard', 'ISOLATE_VOCABULARY_ID',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'isolatevocabulary' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    where database_id = d.database_id);



exit;
