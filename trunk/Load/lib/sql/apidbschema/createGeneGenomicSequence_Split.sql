create table apidb.GeneGenomicSequence_Split (
 geneGenomicSequence_id	NUMBER(10),
 source_id VARCHAR2(255) NOT NULL,
 gene_genomic_sequence CLOB,
 start_min NUMBER(12) NOT NULL,
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
 PRIMARY KEY (geneGenomicSequence_id)
);

create index ggss_source_id_indx  on apidb.GENEGENOMICSEQUENCE_SPLIT(source_id);
CREATE SEQUENCE ApiDB.GeneGenomicSequence_Split_sq;

GRANT SELECT ON apidb.GENEGENOMICSEQUENCE_SPLIT TO gus_r;
GRANT INSERT, UPDATE, DELETE ON apidb.GENEGENOMICSEQUENCE_SPLIT TO gus_w;
GRANT SELECT ON ApiDB.geneGenomicSequence_SPLIT_sq TO gus_w;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'GeneGenomicSequence_Split',
       'Standard', 'geneGenomicSequence_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'GeneGenomicSequence_Split' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);

exit;
