CREATE TABLE apidb.MassSpecSummary (
 mass_spec_summary_id         NUMERIC(12) NOT NULL,
 aa_sequence_id               NUMERIC(12) NOT NULL,
 prediction_algorithm_id      NUMERIC(12),
 external_database_release_id NUMERIC(12),
 developmental_stage          character varying(20),
 is_expressed                 NUMERIC(1),
 NUMERIC_of_spans              NUMERIC(12),
 sequence_count               NUMERIC(12),
 spectrum_count               NUMERIC(12),
 aa_seq_percent_covered       FLOAT(40),
 aa_seq_length                NUMERIC(12),
 aa_seq_molecular_weight      NUMERIC(12),
 aa_seq_pi                    FLOAT(40),
 modification_date            timestamp NOT NULL,
 user_read                    NUMERIC(1) NOT NULL,
 user_write                   NUMERIC(1) NOT NULL,
 group_read                   NUMERIC(1) NOT NULL,
 group_write                  NUMERIC(1) NOT NULL,
 other_read                   NUMERIC(1) NOT NULL,
 other_write                  NUMERIC(1) NOT NULL,
 row_user_id                  NUMERIC(12) NOT NULL,
 row_group_id                 NUMERIC(3) NOT NULL,
 row_project_id               NUMERIC(4) NOT NULL,
 row_alg_invocation_id        NUMERIC(12) NOT NULL
);

ALTER TABLE apidb.MassSpecSummary
ADD CONSTRAINT mss_pk PRIMARY KEY (mass_spec_summary_id);

ALTER TABLE apidb.MassSpecSummary
ADD CONSTRAINT mss_fk1 FOREIGN KEY (aa_sequence_id)
REFERENCES dots.AASequenceImp (aa_sequence_id);

ALTER TABLE apidb.MassSpecSummary
ADD CONSTRAINT mss_fk2 FOREIGN KEY (external_database_release_id)
REFERENCES sres.ExternalDatabaseRelease (external_database_release_id);

CREATE INDEX massspecsumm_rel_sum_idx ON apiDB.Massspecsummary(external_database_release_id,NUMERIC_of_spans,spectrum_count);
CREATE INDEX massspecsumm_devstage_idx ON apiDB.Massspecsummary(developmental_stage,NUMERIC_of_spans,spectrum_count);
CREATE INDEX massspecsumm_aaseqid_idx ON apiDB.Massspecsummary(aa_sequence_id);

------------------------------------------------------------------------------

CREATE SEQUENCE apidb.MassSpecSummary_sq;

------------------------------------------------------------------------------


INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT nextval('core.tableinfo_sq'), 'MassSpecSummary',
       'Standard', 'db_ref_aa_feature_id',
       (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb'), 0, 0, NULL, NULL, 
       1,current_timestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo), 0
WHERE lower('MassSpecSummary') NOT IN (SELECT lower(name) FROM core.TableInfo
        WHERE database_id = (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb'));


