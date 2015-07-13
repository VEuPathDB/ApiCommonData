
CREATE TABLE apidb.RUMIntronFeature (
 RUM_intron_feature_id       NUMBER(10),
 external_database_release_id NUMBER(10) NOT NULL,
 sample_name                  VARCHAR2(100) NOT NULL,
 na_sequence_id               NUMBER(10) NOT NULL,
 mapping_start                     NUMBER(10) NOT NULL,
 mapping_end                     NUMBER(10) NOT NULL,
 score                    NUMBER(10),
 known_intron                    NUMBER(10),
 standard_splice_signal                    NUMBER(10),
 signal_not_canonical                    NUMBER(10),
 ambiguous                    NUMBER(10),
 long_overlap_unique_reads                    NUMBER(10),
 short_overlap_unique_reads                    NUMBER(10),
 long_overlap_nu_reads                    NUMBER(10),
 short_overlap_nu_reads                    NUMBER(10),
 MODIFICATION_DATE            DATE,
 USER_READ                    NUMBER(1),
 USER_WRITE                   NUMBER(1),
 GROUP_READ                   NUMBER(1),
 GROUP_WRITE                  NUMBER(1),
 OTHER_READ                   NUMBER(1),
 OTHER_WRITE                  NUMBER(1),
 ROW_USER_ID                  NUMBER(12),
 ROW_GROUP_ID                 NUMBER(3),
 ROW_PROJECT_ID               NUMBER(4),
 ROW_ALG_INVOCATION_ID        NUMBER(12),
 FOREIGN KEY (external_database_release_id) REFERENCES SRes.ExternalDatabaseRelease,
 PRIMARY KEY (RUM_intron_feature_id)
);

CREATE INDEX apidb.rif_rls_ix
ON apidb.RumIntronFeature
   (external_database_release_id, na_sequence_id, sample_name, mapping_start, 
    mapping_end, rum_intron_feature_id, score, known_intron, 
    standard_splice_signal, signal_not_canonical, ambiguous, 
    long_overlap_unique_reads, short_overlap_unique_reads, 
    long_overlap_nu_reads, short_overlap_nu_reads);

CREATE INDEX apiDB.rif_revfk_idx
  ON apidb.RUMIntronFeature (external_database_release_id, RUM_intron_feature_id) tablespace indx;

CREATE SEQUENCE apidb.RUMIntronFeature_sq;

GRANT insert, select, update, delete ON apidb.RUMIntronFeature TO gus_w;
GRANT select ON apidb.RUMIntronFeature TO gus_r;
GRANT select ON apidb.RUMIntronFeature_sq TO gus_w;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'RUMIntronFeature',
       'Standard', 'RUM_intron_feature_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'rumintronfeature' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

------------------------------------------------------------------------------
exit;
