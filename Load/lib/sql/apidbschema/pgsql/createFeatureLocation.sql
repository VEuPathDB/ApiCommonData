CREATE TABLE apidb.FeatureLocation (
 feature_location_id          NUMERIC(10),
 feature_type                 VARCHAR(30),
 feature_source_id            VARCHAR(80),
 sequence_source_id           VARCHAR(60),
 na_sequence_id               NUMERIC(10),
 na_feature_id                NUMERIC(10),
 start_min                    NUMERIC(12),
 end_max                      NUMERIC(12),
 is_reversed                  NUMERIC(1),
 parent_id                    NUMERIC(10),
 sequence_ontology_id         NUMERIC(10),
 is_top_level                 NUMERIC(1),
 external_database_release_id NUMERIC(10),
 modification_date            DATE,
 user_read                    NUMERIC(1),
 user_write                   NUMERIC(1),
 group_read                   NUMERIC(1),
 group_write                  NUMERIC(1),
 other_read                   NUMERIC(1),
 other_write                  NUMERIC(1),
 row_user_id                  NUMERIC(12),
 row_group_id                 NUMERIC(3),
 row_project_id               NUMERIC(4),
 row_alg_invocation_id        NUMERIC(12),
 FOREIGN KEY (na_feature_id) REFERENCES dots.NaFeatureImp,
 FOREIGN KEY (na_sequence_id) REFERENCES dots.NaSequenceImp,
 FOREIGN KEY (parent_id) REFERENCES dots.NaFeatureImp (na_feature_id),
 FOREIGN KEY (sequence_ontology_id) REFERENCES sres.OntologyTerm (ontology_term_id),
 FOREIGN KEY (external_database_release_id) REFERENCES sres.ExternalDatabaseRelease (external_database_release_id),
 FOREIGN KEY (row_alg_invocation_id) REFERENCES core.AlgorithmInvocation (algorithm_invocation_id),
 PRIMARY KEY (feature_location_id)
);

CREATE INDEX featloc_ix1
ON apidb.FeatureLocation (na_sequence_id, start_min, end_max, is_reversed,
                          sequence_ontology_id, na_feature_id, feature_type, parent_id)
TABLESPACE INDX;

CREATE INDEX featloc_ix2
ON apidb.FeatureLocation (na_feature_id, na_sequence_id, start_min, end_max,
                          is_reversed, sequence_ontology_id, feature_type, parent_id)
TABLESPACE INDX;

CREATE INDEX featloc_ix3
ON apidb.FeatureLocation (na_sequence_id, feature_type, start_min, end_max, is_reversed,
                          sequence_ontology_id, na_feature_id, parent_id)
TABLESPACE INDX;

CREATE INDEX featloc_ix4
ON apidb.FeatureLocation (na_sequence_id, feature_type, end_max, start_min, is_reversed,
                          sequence_ontology_id, na_feature_id, parent_id)
TABLESPACE INDX;

CREATE INDEX featloc_revix2
ON apidb.FeatureLocation (na_feature_id, feature_location_id)
TABLESPACE INDX;

CREATE INDEX featloc_revix3
ON apidb.FeatureLocation (parent_id, feature_location_id)
TABLESPACE INDX;

CREATE INDEX featloc_revix4
ON apidb.FeatureLocation (sequence_ontology_id, feature_location_id)
TABLESPACE INDX;

CREATE INDEX featloc_revix5
ON apidb.FeatureLocation (external_database_release_id, feature_location_id)
TABLESPACE INDX;

CREATE INDEX featloc_revix6
ON apidb.FeatureLocation (row_alg_invocation_id, feature_location_id)
TABLESPACE INDX;

CREATE SEQUENCE apidb.FeatureLocation_sq;

GRANT insert, select, update, delete ON apidb.FeatureLocation TO gus_w;
GRANT select ON apidb.FeatureLocation TO gus_r;
GRANT select ON apidb.FeatureLocation_sq TO gus_w;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'FeatureLocation',
       'Standard', 'feature_location_id',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE LOWER(name) = 'apidb') d
WHERE LOWER('FeatureLocation') NOT IN (SELECT LOWER(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

------------------------------------------------------------------------------

CREATE TABLE apidb.GeneLocation (
 gene_location_id             NUMERIC(10),
 feature_source_id            VARCHAR(80),
 sequence_source_id           VARCHAR(60),
 na_sequence_id               NUMERIC(10),
 na_feature_id                NUMERIC(10),
 start_min                    NUMERIC,
 end_max                      NUMERIC,
 is_reversed                  NUMERIC(1),
 sequence_ontology_id         NUMERIC(10),
 is_top_level                 NUMERIC(1),
 external_database_release_id NUMERIC(10),
 modification_date            DATE,
 user_read                    NUMERIC(1),
 user_write                   NUMERIC(1),
 group_read                   NUMERIC(1),
 group_write                  NUMERIC(1),
 other_read                   NUMERIC(1),
 other_write                  NUMERIC(1),
 row_user_id                  NUMERIC(12),
 row_group_id                 NUMERIC(3),
 row_project_id               NUMERIC(4),
 row_alg_invocation_id        NUMERIC(12),
 FOREIGN KEY (na_feature_id) REFERENCES dots.NaFeatureImp,
 FOREIGN KEY (na_sequence_id) REFERENCES dots.NaSequenceImp,
 FOREIGN KEY (sequence_ontology_id) REFERENCES sres.OntologyTerm (ontology_term_id),
 FOREIGN KEY (external_database_release_id) REFERENCES sres.ExternalDatabaseRelease (external_database_release_id),
 FOREIGN KEY (row_alg_invocation_id) REFERENCES core.AlgorithmInvocation (algorithm_invocation_id),
 PRIMARY KEY (gene_location_id)
);

CREATE INDEX geneloc_ix1
ON apidb.GeneLocation (na_sequence_id, start_min, end_max, is_reversed,
                          sequence_ontology_id, na_feature_id)
TABLESPACE INDX;

CREATE INDEX geneloc_ix2
ON apidb.GeneLocation (na_feature_id, na_sequence_id, start_min, end_max,
                          is_reversed, sequence_ontology_id)
TABLESPACE INDX;

CREATE INDEX geneloc_revix1
ON apidb.GeneLocation (na_sequence_id, gene_location_id)
TABLESPACE INDX;

CREATE INDEX geneloc_revix2
ON apidb.GeneLocation (na_feature_id, gene_location_id)
TABLESPACE INDX;

CREATE INDEX geneloc_revix4
ON apidb.GeneLocation (sequence_ontology_id, gene_location_id)
TABLESPACE INDX;

CREATE INDEX geneloc_revix5
ON apidb.GeneLocation (external_database_release_id, gene_location_id)
TABLESPACE INDX;

CREATE INDEX geneloc_revix6
ON apidb.GeneLocation (row_alg_invocation_id, gene_location_id)
TABLESPACE INDX;

CREATE SEQUENCE apidb.GeneLocation_sq;

GRANT insert, select, update, delete ON apidb.GeneLocation TO gus_w;
GRANT select ON apidb.GeneLocation TO gus_r;
GRANT select ON apidb.GeneLocation_sq TO gus_w;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'GeneLocation',
       'Standard', 'gene_location_id',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE LOWER(name) = 'apidb') d
WHERE LOWER('GeneLocation') NOT IN (SELECT LOWER(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

------------------------------------------------------------------------------

CREATE TABLE apidb.TranscriptLocation (
 transcript_location_id       NUMERIC(10),
 feature_source_id            VARCHAR(80),
 sequence_source_id           VARCHAR(60),
 na_sequence_id               NUMERIC(10),
 na_feature_id                NUMERIC(10),
 start_min                    NUMERIC,
 end_max                      NUMERIC,
 is_reversed                  NUMERIC(1),
 parent_id                    NUMERIC(10),
 sequence_ontology_id         NUMERIC(10),
 is_top_level                 NUMERIC(1),
 external_database_release_id NUMERIC(10),
 modification_date            DATE,
 user_read                    NUMERIC(1),
 user_write                   NUMERIC(1),
 group_read                   NUMERIC(1),
 group_write                  NUMERIC(1),
 other_read                   NUMERIC(1),
 other_write                  NUMERIC(1),
 row_user_id                  NUMERIC(12),
 row_group_id                 NUMERIC(3),
 row_project_id               NUMERIC(4),
 row_alg_invocation_id        NUMERIC(12),
 FOREIGN KEY (na_feature_id) REFERENCES dots.NaFeatureImp,
 FOREIGN KEY (na_sequence_id) REFERENCES dots.NaSequenceImp,
 FOREIGN KEY (parent_id) REFERENCES dots.NaFeatureImp (na_feature_id),
 FOREIGN KEY (sequence_ontology_id) REFERENCES sres.OntologyTerm (ontology_term_id),
 FOREIGN KEY (external_database_release_id) REFERENCES sres.ExternalDatabaseRelease (external_database_release_id),
 FOREIGN KEY (row_alg_invocation_id) REFERENCES core.AlgorithmInvocation (algorithm_invocation_id),
 PRIMARY KEY (transcript_location_id)
);

CREATE INDEX transcriptloc_ix1
ON apidb.TranscriptLocation (na_sequence_id, start_min, end_max, is_reversed,
                          sequence_ontology_id, na_feature_id, is_top_level)
TABLESPACE INDX;

CREATE INDEX transcriptloc_ix2
ON apidb.TranscriptLocation (na_feature_id, na_sequence_id, start_min, end_max,
                          is_reversed, sequence_ontology_id, is_top_level)
TABLESPACE INDX;

CREATE INDEX transcriptloc_revix1
ON apidb.TranscriptLocation (na_sequence_id, transcript_location_id)
TABLESPACE INDX;

CREATE INDEX transcriptloc_revix2
ON apidb.TranscriptLocation (na_feature_id, transcript_location_id)
TABLESPACE INDX;

CREATE INDEX transcriptloc_revix3
ON apidb.TranscriptLocation (parent_id, transcript_location_id)
TABLESPACE INDX;

CREATE INDEX transcriptloc_revix4
ON apidb.TranscriptLocation (sequence_ontology_id, transcript_location_id)
TABLESPACE INDX;

CREATE INDEX transcriptloc_revix5
ON apidb.TranscriptLocation (external_database_release_id, transcript_location_id)
TABLESPACE INDX;

CREATE INDEX transcriptloc_revix6
ON apidb.TranscriptLocation (row_alg_invocation_id, transcript_location_id)
TABLESPACE INDX;

CREATE SEQUENCE apidb.TranscriptLocation_sq;

GRANT insert, select, update, delete ON apidb.TranscriptLocation TO gus_w;
GRANT select ON apidb.TranscriptLocation TO gus_r;
GRANT select ON apidb.TranscriptLocation_sq TO gus_w;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'TranscriptLocation',
       'Standard', 'transcript_location_id',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE LOWER(name) = 'apidb') d
WHERE LOWER('TranscriptLocation') NOT IN (SELECT LOWER(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

------------------------------------------------------------------------------
CREATE TABLE apidb.ExonLocation (
 exon_location_id             NUMERIC(10),
 feature_source_id            VARCHAR(80),
 sequence_source_id           VARCHAR(60),
 na_sequence_id               NUMERIC(10),
 na_feature_id                NUMERIC(10),
 start_min                    NUMERIC,
 end_max                      NUMERIC,
 is_reversed                  NUMERIC(1),
 parent_id                    NUMERIC(10),
 sequence_ontology_id         NUMERIC(10),
 is_top_level                 NUMERIC(1),
 external_database_release_id NUMERIC(10),
 modification_date            DATE,
 user_read                    NUMERIC(1),
 user_write                   NUMERIC(1),
 group_read                   NUMERIC(1),
 group_write                  NUMERIC(1),
 other_read                   NUMERIC(1),
 other_write                  NUMERIC(1),
 row_user_id                  NUMERIC(12),
 row_group_id                 NUMERIC(3),
 row_project_id               NUMERIC(4),
 row_alg_invocation_id        NUMERIC(12),
 FOREIGN KEY (na_feature_id) REFERENCES dots.NaFeatureImp,
 FOREIGN KEY (na_sequence_id) REFERENCES dots.NaSequenceImp,
 FOREIGN KEY (parent_id) REFERENCES dots.NaFeatureImp (na_feature_id),
 FOREIGN KEY (sequence_ontology_id) REFERENCES sres.OntologyTerm (ontology_term_id),
 FOREIGN KEY (external_database_release_id) REFERENCES sres.ExternalDatabaseRelease (external_database_release_id),
 FOREIGN KEY (row_alg_invocation_id) REFERENCES core.AlgorithmInvocation (algorithm_invocation_id),
 PRIMARY KEY (exon_location_id)
);

CREATE INDEX exonloc_ix1
ON apidb.ExonLocation (na_sequence_id, start_min, end_max, is_reversed,
                          sequence_ontology_id, na_feature_id)
TABLESPACE INDX;

CREATE INDEX exonloc_ix2
ON apidb.ExonLocation (na_feature_id, na_sequence_id, start_min, end_max,
                          is_reversed, sequence_ontology_id)
TABLESPACE INDX;

CREATE INDEX exonloc_revix1
ON apidb.ExonLocation (na_sequence_id, exon_location_id)
TABLESPACE INDX;

CREATE INDEX exonloc_revix2
ON apidb.ExonLocation (na_feature_id, exon_location_id)
TABLESPACE INDX;

CREATE INDEX exonloc_revix3
ON apidb.ExonLocation (parent_id, exon_location_id)
TABLESPACE INDX;

CREATE INDEX exonloc_revix4
ON apidb.ExonLocation (sequence_ontology_id, exon_location_id)
TABLESPACE INDX;

CREATE INDEX exonloc_revix5
ON apidb.ExonLocation (external_database_release_id, exon_location_id)
TABLESPACE INDX;

CREATE INDEX exonloc_revix6
ON apidb.ExonLocation (row_alg_invocation_id, exon_location_id)
TABLESPACE INDX;

CREATE SEQUENCE apidb.ExonLocation_sq;

GRANT insert, select, update, delete ON apidb.ExonLocation TO gus_w;
GRANT select ON apidb.ExonLocation TO gus_r;
GRANT select ON apidb.ExonLocation_sq TO gus_w;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'ExonLocation',
       'Standard', 'exon_location_id',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE LOWER(name) = 'apidb') d
WHERE LOWER('ExonLocation') NOT IN (SELECT LOWER(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

------------------------------------------------------------------------------
CREATE TABLE apidb.CdsLocation (
 cds_location_id              NUMERIC(10),
 protein_source_id            VARCHAR(80),
 transcript_source_id         VARCHAR(80),
 sequence_source_id           VARCHAR(60),
 na_sequence_id               NUMERIC(10),
 start_min                    NUMERIC,
 end_max                      NUMERIC,
 is_reversed                  NUMERIC(1),
 parent_id                    NUMERIC(10),
 is_top_level                 NUMERIC(1),
 external_database_release_id NUMERIC(10),
 modification_date            DATE,
 user_read                    NUMERIC(1),
 user_write                   NUMERIC(1),
 group_read                   NUMERIC(1),
 group_write                  NUMERIC(1),
 other_read                   NUMERIC(1),
 other_write                  NUMERIC(1),
 row_user_id                  NUMERIC(12),
 row_group_id                 NUMERIC(3),
 row_project_id               NUMERIC(4),
 row_alg_invocation_id        NUMERIC(12),
 FOREIGN KEY (na_sequence_id) REFERENCES dots.NaSequenceImp,
 FOREIGN KEY (parent_id) REFERENCES dots.NaFeatureImp (na_feature_id),
 FOREIGN KEY (external_database_release_id) REFERENCES sres.ExternalDatabaseRelease (external_database_release_id),
 FOREIGN KEY (row_alg_invocation_id) REFERENCES core.AlgorithmInvocation (algorithm_invocation_id),
 PRIMARY KEY (cds_location_id)
);

CREATE INDEX cdsloc_ix1
ON apidb.CdsLocation (na_sequence_id, start_min, end_max, is_reversed,
                      parent_id)
TABLESPACE INDX;

CREATE INDEX cdsloc_ix2
ON apidb.CdsLocation (parent_id, na_sequence_id, start_min, end_max,
                      is_reversed)
TABLESPACE INDX;

CREATE INDEX cdsloc_revix1
ON apidb.CdsLocation (na_sequence_id, cds_location_id)
TABLESPACE INDX;

CREATE INDEX cdsloc_revix3
ON apidb.CdsLocation (parent_id, cds_location_id)
TABLESPACE INDX;

CREATE INDEX cdsloc_revix5
ON apidb.CdsLocation (external_database_release_id, cds_location_id)
TABLESPACE INDX;

CREATE INDEX cdsloc_revix6
ON apidb.CdsLocation (row_alg_invocation_id, cds_location_id)
TABLESPACE INDX;

CREATE SEQUENCE apidb.CdsLocation_sq;

GRANT insert, select, update, delete ON apidb.CdsLocation TO gus_w;
GRANT select ON apidb.CdsLocation TO gus_r;
GRANT select ON apidb.CdsLocation_sq TO gus_w;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'CdsLocation',
       'Standard', 'cds_location_id',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE LOWER(name) = 'apidb') d
WHERE LOWER('CdsLocation') NOT IN (SELECT LOWER(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

------------------------------------------------------------------------------
CREATE TABLE apidb.UtrLocation (
 utr_location_id              NUMERIC(10),
 sequence_source_id           VARCHAR(60),
 na_sequence_id               NUMERIC(10),
 start_min                    NUMERIC,
 end_max                      NUMERIC,
 is_reversed                  NUMERIC(1),
 direction                    NUMERIC(1),
 parent_id                    NUMERIC(10),
 is_top_level                 NUMERIC(1),
 external_database_release_id NUMERIC(10),
 modification_date            DATE,
 user_read                    NUMERIC(1),
 user_write                   NUMERIC(1),
 group_read                   NUMERIC(1),
 group_write                  NUMERIC(1),
 other_read                   NUMERIC(1),
 other_write                  NUMERIC(1),
 row_user_id                  NUMERIC(12),
 row_group_id                 NUMERIC(3),
 row_project_id               NUMERIC(4),
 row_alg_invocation_id        NUMERIC(12),
 FOREIGN KEY (na_sequence_id) REFERENCES dots.NaSequenceImp,
 FOREIGN KEY (parent_id) REFERENCES dots.NaFeatureImp (na_feature_id),
 FOREIGN KEY (external_database_release_id) REFERENCES sres.ExternalDatabaseRelease (external_database_release_id),
 FOREIGN KEY (row_alg_invocation_id) REFERENCES core.AlgorithmInvocation (algorithm_invocation_id),
 PRIMARY KEY (utr_location_id)
);

CREATE INDEX utrloc_ix1
ON apidb.UtrLocation (na_sequence_id, start_min, end_max, is_reversed,
                      parent_id)
TABLESPACE INDX;

CREATE INDEX utrloc_ix2
ON apidb.UtrLocation (parent_id, na_sequence_id, start_min, end_max,
                          is_reversed)
TABLESPACE INDX;

CREATE INDEX utrloc_revix1
ON apidb.UtrLocation (na_sequence_id, utr_location_id)
TABLESPACE INDX;

CREATE INDEX utrloc_revix3
ON apidb.UtrLocation (parent_id, utr_location_id)
TABLESPACE INDX;

CREATE INDEX utrloc_revix5
ON apidb.UtrLocation (external_database_release_id, utr_location_id)
TABLESPACE INDX;

CREATE INDEX utrloc_revix6
ON apidb.UtrLocation (row_alg_invocation_id, utr_location_id)
TABLESPACE INDX;

CREATE SEQUENCE apidb.UtrLocation_sq;

GRANT insert, select, update, delete ON apidb.UtrLocation TO gus_w;
GRANT select ON apidb.UtrLocation TO gus_r;
GRANT select ON apidb.UtrLocation_sq TO gus_w;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'UtrLocation',
       'Standard', 'utr_location_id',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE LOWER(name) = 'apidb') d
WHERE LOWER('UtrLocation') NOT IN (SELECT LOWER(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

------------------------------------------------------------------------------
CREATE TABLE apidb.IntronLocation (
 intron_location_id           NUMERIC(10),
 sequence_source_id           VARCHAR(60),
 na_sequence_id               NUMERIC(10),
 start_min                    NUMERIC,
 end_max                      NUMERIC,
 is_reversed                  NUMERIC(1),
 parent_id                    NUMERIC(10),
 is_top_level                 NUMERIC(1),
 external_database_release_id NUMERIC(10),
 modification_date            DATE,
 user_read                    NUMERIC(1),
 user_write                   NUMERIC(1),
 group_read                   NUMERIC(1),
 group_write                  NUMERIC(1),
 other_read                   NUMERIC(1),
 other_write                  NUMERIC(1),
 row_user_id                  NUMERIC(12),
 row_group_id                 NUMERIC(3),
 row_project_id               NUMERIC(4),
 row_alg_invocation_id        NUMERIC(12),
 FOREIGN KEY (na_sequence_id) REFERENCES dots.NaSequenceImp,
 FOREIGN KEY (parent_id) REFERENCES dots.NaFeatureImp (na_feature_id),
 FOREIGN KEY (external_database_release_id) REFERENCES sres.ExternalDatabaseRelease (external_database_release_id),
 FOREIGN KEY (row_alg_invocation_id) REFERENCES core.AlgorithmInvocation (algorithm_invocation_id),
 PRIMARY KEY (intron_location_id)
);

CREATE INDEX intronloc_ix1
ON apidb.IntronLocation (na_sequence_id, start_min, end_max, is_reversed,
                      parent_id)
TABLESPACE INDX;

CREATE INDEX intronloc_ix2
ON apidb.IntronLocation (parent_id, na_sequence_id, start_min, end_max,
                          is_reversed)
TABLESPACE INDX;

CREATE INDEX intronloc_revix1
ON apidb.IntronLocation (na_sequence_id, intron_location_id)
TABLESPACE INDX;

CREATE INDEX intronloc_revix3
ON apidb.IntronLocation (parent_id, intron_location_id)
TABLESPACE INDX;

CREATE INDEX intronloc_revix5
ON apidb.IntronLocation (external_database_release_id, intron_location_id)
TABLESPACE INDX;

CREATE INDEX intronloc_revix6
ON apidb.IntronLocation (row_alg_invocation_id, intron_location_id)
TABLESPACE INDX;

CREATE SEQUENCE apidb.IntronLocation_sq;

GRANT insert, select, update, delete ON apidb.IntronLocation TO gus_w;
GRANT select ON apidb.IntronLocation TO gus_r;
GRANT select ON apidb.IntronLocation_sq TO gus_w;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'IntronLocation',
       'Standard', 'intron_location_id',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE LOWER(name) = 'apidb') d
WHERE LOWER('IntronLocation') NOT IN (SELECT LOWER(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

------------------------------------------------------------------------------
