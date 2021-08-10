CREATE TABLE apidb.MassSpecSummary (
 mass_spec_summary_id         NUMBER(12) NOT NULL,
 aa_sequence_id               NUMBER(12) NOT NULL,
 protocol_app_node_id         NUMBER(10) NOT NULL,
 prediction_algorithm_id      NUMBER(12),
 external_database_release_id NUMBER(12),
 number_of_spans              NUMBER(12),
 sequence_count               NUMBER(12),
 spectrum_count               NUMBER(12),
 aa_seq_percent_covered       FLOAT(126),
 modification_date            date NOT NULL,
 user_read                    NUMBER(1) NOT NULL,
 user_write                   NUMBER(1) NOT NULL,
 group_read                   NUMBER(1) NOT NULL,
 group_write                  NUMBER(1) NOT NULL,
 other_read                   NUMBER(1) NOT NULL,
 other_write                  NUMBER(1) NOT NULL,
 row_user_id                  NUMBER(12) NOT NULL,
 row_group_id                 NUMBER(3) NOT NULL,
 row_project_id               NUMBER(4) NOT NULL,
 row_alg_invocation_id        NUMBER(12) NOT NULL
);

ALTER TABLE apidb.MassSpecSummary
ADD CONSTRAINT mss_pk PRIMARY KEY (mass_spec_summary_id);

ALTER TABLE apidb.MassSpecSummary
ADD CONSTRAINT mss_fk1 FOREIGN KEY (aa_sequence_id)
REFERENCES dots.AASequenceImp (aa_sequence_id);


ALTER TABLE apidb.MassSpecSummary
ADD CONSTRAINT mss_fk2 FOREIGN KEY (external_database_release_id)
REFERENCES sres.ExternalDatabaseRelease (external_database_release_id);

ALTER TABLE apidb.MassSpecSummary
ADD CONSTRAINT mss_fk3 FOREIGN KEY (protocol_app_node_id)
REFERENCES study.protocolappnode (protocol_app_node_id);

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.MassSpecSummary TO gus_w;
GRANT SELECT ON apidb.MassSpecSummary TO gus_r;

CREATE INDEX apiDB.massspecsumm_rel_sum_idx ON apiDB.Massspecsummary(external_database_release_id,number_of_spans,spectrum_count, mass_spec_summary_id);
CREATE INDEX apiDB.massspecsumm_aaseqid_idx ON apiDB.Massspecsummary(aa_sequence_id);
CREATE INDEX apiDB.massspecsumm_protAppNd_idx ON apiDB.Massspecsummary(protocol_app_node_id);

GRANT REFERENCES ON apidb.MassSpecSummary to dots;

ALTER TABLE DoTS.AAFeatureImp
ADD CONSTRAINT mss_id FOREIGN KEY (mass_spec_summary_id)
REFERENCES apidb.massspecsummary (mass_spec_summary_id);


------------------------------------------------------------------------------

CREATE SEQUENCE apidb.MassSpecSummary_sq;

GRANT SELECT ON apidb.MassSpecSummary_sq TO gus_r;
GRANT SELECT ON apidb.MassSpecSummary_sq TO gus_w;

------------------------------------------------------------------------------

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'MassSpecSummary',
       'Standard', 'mass_spec_summary_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'massspecsummary' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

exit;
