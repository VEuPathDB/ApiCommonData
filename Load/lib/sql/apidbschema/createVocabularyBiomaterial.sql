CREATE TABLE ApiDB.VocabularyBiomaterial (
 vocabulary_biomaterial_id NUMBER(10),
 bio_material_id             NUMBER(10) NOT NULL,
 isolate_vocabulary_id       NUMBER(10) NOT NULL,
 MODIFICATION_DATE     DATE,
 USER_READ             NUMBER(1),
 USER_WRITE            NUMBER(1),
 GROUP_READ            NUMBER(1),
 GROUP_WRITE           NUMBER(1),
 OTHER_READ            NUMBER(1),
 OTHER_WRITE           NUMBER(1),
 ROW_USER_ID           NUMBER(12),
 ROW_GROUP_ID          NUMBER(3),
 ROW_PROJECT_ID        NUMBER(4),
 ROW_ALG_INVOCATION_ID NUMBER(12),
 PRIMARY KEY (vocabulary_biomaterial_id),
 FOREIGN KEY (bio_material_id) REFERENCES Study.Biomaterial (bio_material_id),
 FOREIGN KEY (isolate_vocabulary_id) REFERENCES ApiDB.IsolateVocabulary (isolate_vocabulary_id)
);

CREATE SEQUENCE ApiDB.VocabularyBiomaterial_sq;

GRANT insert, select, update, delete ON ApiDB.VocabularyBiomaterial TO gus_w;
GRANT select ON ApiDB.VocabularyBiomaterial TO gus_r;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'VocabularyBiomaterial',
       'Standard', 'vocabulary_biomaterial_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'VocabularyBiomaterial' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);




exit;
