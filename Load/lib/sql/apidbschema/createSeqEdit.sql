CREATE TABLE ApiDB.SeqEdit (
   SEQ_EDIT_ID                  NUMBER(12)      NOT NULL,
   SOURCE_ID                    VARCHAR2(80)    NOT NULL,
   SEQUENCE_TYPE                VARCHAR2(15)    NOT NULL,
   SEQUENCE_ONTOLOGY_ID         NUMBER(10)      NOT NULL,
   START_MIN                    NUMBER(12)      NOT NULL,
   END_MAX                      NUMBER(12)      NOT NULL,
   SEQUENCE                     VARCHAR2(4000)  NOT NULL,
   MODIFICATION_DATE            DATE            NOT NULL,
   USER_READ                    NUMBER(1)       NOT NULL,
   USER_WRITE                   NUMBER(1)       NOT NULL,
   GROUP_READ                   NUMBER(1)       NOT NULL,
   GROUP_WRITE                  NUMBER(1)       NOT NULL,
   OTHER_READ                   NUMBER(1)       NOT NULL,
   OTHER_WRITE                  NUMBER(1)       NOT NULL,
   ROW_USER_ID                  NUMBER(12)      NOT NULL,
   ROW_GROUP_ID                 NUMBER(3)       NOT NULL,
   ROW_PROJECT_ID               NUMBER(4)       NOT NULL,
   ROW_ALG_INVOCATION_ID        NUMBER(12)      NOT NULL,
   PRIMARY KEY (SEQ_EDIT_ID),
   FOREIGN KEY (SEQUENCE_ONTOLOGY_ID) REFERENCES SRes.OntologyTerm (ONTOLOGY_TERM_ID) 
);

GRANT INSERT, SELECT, UPDATE, DELETE ON ApiDB.SeqEdit TO gus_w;  
GRANT SELECT ON ApiDB.SeqEdit TO gus_r;  

CREATE INDEX apidb.seqedit_idIx ON apidb.SeqEdit(source_id, sequence_type) TABLESPACE indx;

-----------
CREATE SEQUENCE ApiDB.SeqEdit_SQ;    

GRANT SELECT ON ApiDB.SeqEdit_SQ TO gus_r;
GRANT SELECT ON ApiDB.SeqEdit_SQ TO gus_w;

----------------------

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable,
     modification_date, user_read, user_write, group_read, group_write,
     other_read, other_write, row_user_id, row_group_id, row_project_id,
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'SeqEdit',
       'Standard', 'SEQ_EDIT_ID',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'seqedit' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

exit;
