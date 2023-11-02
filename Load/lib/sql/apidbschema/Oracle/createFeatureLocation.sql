CREATE TABLE apidb.FeatureLocation (
 feature_location_id          NUMBER(10),
 feature_type                 VARCHAR2(30),
 feature_source_id            VARCHAR2(80),
 sequence_source_id           VARCHAR2(60),
 na_sequence_id               NUMBER(10),
 na_feature_id                NUMBER(10),
 start_min                    NUMBER(12),
 end_max                      NUMBER(12),
 is_reversed                  NUMBER(1),
 parent_id                    NUMBER(10),
 sequence_ontology_id         NUMBER(10),
 is_top_level                 NUMBER(1),
 external_database_release_id NUMBER(10),
 modification_date            DATE,
 user_read                    NUMBER(1),
 user_write                   NUMBER(1),
 group_read                   NUMBER(1),
 group_write                  NUMBER(1),
 other_read                   NUMBER(1),
 other_write                  NUMBER(1),
 row_user_id                  NUMBER(12),
 row_group_id                 NUMBER(3),
 row_project_id               NUMBER(4),
 row_alg_invocation_id        NUMBER(12),
 FOREIGN KEY (na_feature_id) REFERENCES dots.NaFeatureImp,
 FOREIGN KEY (na_sequence_id) REFERENCES dots.NaSequenceImp,
 FOREIGN KEY (parent_id) REFERENCES dots.NaFeatureImp (na_feature_id),
 FOREIGN KEY (sequence_ontology_id) REFERENCES sres.OntologyTerm (ontology_term_id),
 FOREIGN KEY (external_database_release_id) REFERENCES sres.ExternalDatabaseRelease (external_database_release_id),
 FOREIGN KEY (row_alg_invocation_id) REFERENCES core.AlgorithmInvocation (algorithm_invocation_id),
 PRIMARY KEY (feature_location_id)
);

CREATE INDEX apidb.featloc_ix1
ON apidb.FeatureLocation (na_sequence_id, start_min, end_max, is_reversed,
                          sequence_ontology_id, na_feature_id, feature_type, parent_id)
TABLESPACE INDX;

CREATE INDEX apidb.featloc_ix2
ON apidb.FeatureLocation (na_feature_id, na_sequence_id, start_min, end_max,
                          is_reversed, sequence_ontology_id, feature_type, parent_id)
TABLESPACE INDX;

CREATE INDEX apidb.featloc_ix3
ON apidb.FeatureLocation (na_sequence_id, feature_type, start_min, end_max, is_reversed,
                          sequence_ontology_id, na_feature_id, parent_id)
TABLESPACE INDX;

CREATE INDEX apidb.featloc_ix4
ON apidb.FeatureLocation (na_sequence_id, feature_type, end_max, start_min, is_reversed,
                          sequence_ontology_id, na_feature_id, parent_id)
TABLESPACE INDX;

CREATE INDEX apidb.featloc_revix2
ON apidb.FeatureLocation (na_feature_id, feature_location_id)
TABLESPACE INDX;

CREATE INDEX apidb.featloc_revix3
ON apidb.FeatureLocation (parent_id, feature_location_id)
TABLESPACE INDX;

CREATE INDEX apidb.featloc_revix4
ON apidb.FeatureLocation (sequence_ontology_id, feature_location_id)
TABLESPACE INDX;

CREATE INDEX apidb.featloc_revix5
ON apidb.FeatureLocation (external_database_release_id, feature_location_id)
TABLESPACE INDX;

CREATE INDEX apidb.featloc_revix6
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
SELECT core.tableinfo_sq.nextval, 'FeatureLocation',
       'Standard', 'feature_location_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE LOWER(name) = 'apidb') d
WHERE LOWER('FeatureLocation') NOT IN (SELECT LOWER(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

------------------------------------------------------------------------------

CREATE TABLE apidb.GeneLocation (
 gene_location_id             NUMBER(10),
 feature_source_id            VARCHAR2(80),
 sequence_source_id           VARCHAR2(60),
 na_sequence_id               NUMBER(10),
 na_feature_id                NUMBER(10),
 start_min                    NUMBER,
 end_max                      NUMBER,
 is_reversed                  NUMBER(1),
 sequence_ontology_id         NUMBER(10),
 is_top_level                 NUMBER(1),
 external_database_release_id NUMBER(10),
 modification_date            DATE,
 user_read                    NUMBER(1),
 user_write                   NUMBER(1),
 group_read                   NUMBER(1),
 group_write                  NUMBER(1),
 other_read                   NUMBER(1),
 other_write                  NUMBER(1),
 row_user_id                  NUMBER(12),
 row_group_id                 NUMBER(3),
 row_project_id               NUMBER(4),
 row_alg_invocation_id        NUMBER(12),
 FOREIGN KEY (na_feature_id) REFERENCES dots.NaFeatureImp,
 FOREIGN KEY (na_sequence_id) REFERENCES dots.NaSequenceImp,
 FOREIGN KEY (sequence_ontology_id) REFERENCES sres.OntologyTerm (ontology_term_id),
 FOREIGN KEY (external_database_release_id) REFERENCES sres.ExternalDatabaseRelease (external_database_release_id),
 FOREIGN KEY (row_alg_invocation_id) REFERENCES core.AlgorithmInvocation (algorithm_invocation_id),
 PRIMARY KEY (gene_location_id)
);

CREATE INDEX apidb.geneloc_ix1
ON apidb.GeneLocation (na_sequence_id, start_min, end_max, is_reversed,
                          sequence_ontology_id, na_feature_id)
TABLESPACE INDX;

CREATE INDEX apidb.geneloc_ix2
ON apidb.GeneLocation (na_feature_id, na_sequence_id, start_min, end_max,
                          is_reversed, sequence_ontology_id)
TABLESPACE INDX;

CREATE INDEX apidb.geneloc_revix1
ON apidb.GeneLocation (na_sequence_id, gene_location_id)
TABLESPACE INDX;

CREATE INDEX apidb.geneloc_revix2
ON apidb.GeneLocation (na_feature_id, gene_location_id)
TABLESPACE INDX;

CREATE INDEX apidb.geneloc_revix4
ON apidb.GeneLocation (sequence_ontology_id, gene_location_id)
TABLESPACE INDX;

CREATE INDEX apidb.geneloc_revix5
ON apidb.GeneLocation (external_database_release_id, gene_location_id)
TABLESPACE INDX;

CREATE INDEX apidb.geneloc_revix6
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
SELECT core.tableinfo_sq.nextval, 'GeneLocation',
       'Standard', 'gene_location_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE LOWER(name) = 'apidb') d
WHERE LOWER('GeneLocation') NOT IN (SELECT LOWER(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

------------------------------------------------------------------------------

CREATE TABLE apidb.TranscriptLocation (
 transcript_location_id             NUMBER(10),
 feature_source_id            VARCHAR2(80),
 sequence_source_id           VARCHAR2(60),
 na_sequence_id               NUMBER(10),
 na_feature_id                NUMBER(10),
 start_min                    NUMBER,
 end_max                      NUMBER,
 is_reversed                  NUMBER(1),
 parent_id                    NUMBER(10),
 sequence_ontology_id         NUMBER(10),
 is_top_level                 NUMBER(1),
 external_database_release_id NUMBER(10),
 modification_date            DATE,
 user_read                    NUMBER(1),
 user_write                   NUMBER(1),
 group_read                   NUMBER(1),
 group_write                  NUMBER(1),
 other_read                   NUMBER(1),
 other_write                  NUMBER(1),
 row_user_id                  NUMBER(12),
 row_group_id                 NUMBER(3),
 row_project_id               NUMBER(4),
 row_alg_invocation_id        NUMBER(12),
 FOREIGN KEY (na_feature_id) REFERENCES dots.NaFeatureImp,
 FOREIGN KEY (na_sequence_id) REFERENCES dots.NaSequenceImp,
 FOREIGN KEY (parent_id) REFERENCES dots.NaFeatureImp (na_feature_id),
 FOREIGN KEY (sequence_ontology_id) REFERENCES sres.OntologyTerm (ontology_term_id),
 FOREIGN KEY (external_database_release_id) REFERENCES sres.ExternalDatabaseRelease (external_database_release_id),
 FOREIGN KEY (row_alg_invocation_id) REFERENCES core.AlgorithmInvocation (algorithm_invocation_id),
 PRIMARY KEY (transcript_location_id)
);

CREATE INDEX apidb.transcriptloc_ix1
ON apidb.TranscriptLocation (na_sequence_id, start_min, end_max, is_reversed,
                          sequence_ontology_id, na_feature_id, is_top_level)
TABLESPACE INDX;

CREATE INDEX apidb.transcriptloc_ix2
ON apidb.TranscriptLocation (na_feature_id, na_sequence_id, start_min, end_max,
                          is_reversed, sequence_ontology_id, is_top_level)
TABLESPACE INDX;

CREATE INDEX apidb.transcriptloc_revix1
ON apidb.TranscriptLocation (na_sequence_id, transcript_location_id)
TABLESPACE INDX;

CREATE INDEX apidb.transcriptloc_revix2
ON apidb.TranscriptLocation (na_feature_id, transcript_location_id)
TABLESPACE INDX;

CREATE INDEX apidb.transcriptloc_revix3
ON apidb.TranscriptLocation (parent_id, transcript_location_id)
TABLESPACE INDX;

CREATE INDEX apidb.transcriptloc_revix4
ON apidb.TranscriptLocation (sequence_ontology_id, transcript_location_id)
TABLESPACE INDX;

CREATE INDEX apidb.transcriptloc_revix5
ON apidb.TranscriptLocation (external_database_release_id, transcript_location_id)
TABLESPACE INDX;

CREATE INDEX apidb.transcriptloc_revix6
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
SELECT core.tableinfo_sq.nextval, 'TranscriptLocation',
       'Standard', 'transcript_location_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE LOWER(name) = 'apidb') d
WHERE LOWER('TranscriptLocation') NOT IN (SELECT LOWER(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

------------------------------------------------------------------------------
CREATE TABLE apidb.ExonLocation (
 exon_location_id             NUMBER(10),
 feature_source_id            VARCHAR2(80),
 sequence_source_id           VARCHAR2(60),
 na_sequence_id               NUMBER(10),
 na_feature_id                NUMBER(10),
 start_min                    NUMBER,
 end_max                      NUMBER,
 is_reversed                  NUMBER(1),
 parent_id                    NUMBER(10),
 sequence_ontology_id         NUMBER(10),
 is_top_level                 NUMBER(1),
 external_database_release_id NUMBER(10),
 modification_date            DATE,
 user_read                    NUMBER(1),
 user_write                   NUMBER(1),
 group_read                   NUMBER(1),
 group_write                  NUMBER(1),
 other_read                   NUMBER(1),
 other_write                  NUMBER(1),
 row_user_id                  NUMBER(12),
 row_group_id                 NUMBER(3),
 row_project_id               NUMBER(4),
 row_alg_invocation_id        NUMBER(12),
 FOREIGN KEY (na_feature_id) REFERENCES dots.NaFeatureImp,
 FOREIGN KEY (na_sequence_id) REFERENCES dots.NaSequenceImp,
 FOREIGN KEY (parent_id) REFERENCES dots.NaFeatureImp (na_feature_id),
 FOREIGN KEY (sequence_ontology_id) REFERENCES sres.OntologyTerm (ontology_term_id),
 FOREIGN KEY (external_database_release_id) REFERENCES sres.ExternalDatabaseRelease (external_database_release_id),
 FOREIGN KEY (row_alg_invocation_id) REFERENCES core.AlgorithmInvocation (algorithm_invocation_id),
 PRIMARY KEY (exon_location_id)
);

CREATE INDEX apidb.exonloc_ix1
ON apidb.ExonLocation (na_sequence_id, start_min, end_max, is_reversed,
                          sequence_ontology_id, na_feature_id)
TABLESPACE INDX;

CREATE INDEX apidb.exonloc_ix2
ON apidb.ExonLocation (na_feature_id, na_sequence_id, start_min, end_max,
                          is_reversed, sequence_ontology_id)
TABLESPACE INDX;

CREATE INDEX apidb.exonloc_revix1
ON apidb.ExonLocation (na_sequence_id, exon_location_id)
TABLESPACE INDX;

CREATE INDEX apidb.exonloc_revix2
ON apidb.ExonLocation (na_feature_id, exon_location_id)
TABLESPACE INDX;

CREATE INDEX apidb.exonloc_revix3
ON apidb.ExonLocation (parent_id, exon_location_id)
TABLESPACE INDX;

CREATE INDEX apidb.exonloc_revix4
ON apidb.ExonLocation (sequence_ontology_id, exon_location_id)
TABLESPACE INDX;

CREATE INDEX apidb.exonloc_revix5
ON apidb.ExonLocation (external_database_release_id, exon_location_id)
TABLESPACE INDX;

CREATE INDEX apidb.exonloc_revix6
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
SELECT core.tableinfo_sq.nextval, 'ExonLocation',
       'Standard', 'exon_location_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE LOWER(name) = 'apidb') d
WHERE LOWER('ExonLocation') NOT IN (SELECT LOWER(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

------------------------------------------------------------------------------
CREATE TABLE apidb.CdsLocation (
 cds_location_id              NUMBER(10),
 protein_source_id            VARCHAR2(80),
 transcript_source_id         VARCHAR2(80),
 sequence_source_id           VARCHAR2(60),
 na_sequence_id               NUMBER(10),
 start_min                    NUMBER,
 end_max                      NUMBER,
 is_reversed                  NUMBER(1),
 parent_id                    NUMBER(10),
 is_top_level                 NUMBER(1),
 external_database_release_id NUMBER(10),
 modification_date            DATE,
 user_read                    NUMBER(1),
 user_write                   NUMBER(1),
 group_read                   NUMBER(1),
 group_write                  NUMBER(1),
 other_read                   NUMBER(1),
 other_write                  NUMBER(1),
 row_user_id                  NUMBER(12),
 row_group_id                 NUMBER(3),
 row_project_id               NUMBER(4),
 row_alg_invocation_id        NUMBER(12),
 FOREIGN KEY (na_sequence_id) REFERENCES dots.NaSequenceImp,
 FOREIGN KEY (parent_id) REFERENCES dots.NaFeatureImp (na_feature_id),
 FOREIGN KEY (external_database_release_id) REFERENCES sres.ExternalDatabaseRelease (external_database_release_id),
 FOREIGN KEY (row_alg_invocation_id) REFERENCES core.AlgorithmInvocation (algorithm_invocation_id),
 PRIMARY KEY (cds_location_id)
);

CREATE INDEX apidb.cdsloc_ix1
ON apidb.CdsLocation (na_sequence_id, start_min, end_max, is_reversed,
                      parent_id)
TABLESPACE INDX;

CREATE INDEX apidb.cdsloc_ix2
ON apidb.CdsLocation (parent_id, na_sequence_id, start_min, end_max,
                      is_reversed)
TABLESPACE INDX;

CREATE INDEX apidb.cdsloc_revix1
ON apidb.CdsLocation (na_sequence_id, cds_location_id)
TABLESPACE INDX;

CREATE INDEX apidb.cdsloc_revix3
ON apidb.CdsLocation (parent_id, cds_location_id)
TABLESPACE INDX;

CREATE INDEX apidb.cdsloc_revix5
ON apidb.CdsLocation (external_database_release_id, cds_location_id)
TABLESPACE INDX;

CREATE INDEX apidb.cdsloc_revix6
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
SELECT core.tableinfo_sq.nextval, 'CdsLocation',
       'Standard', 'cds_location_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE LOWER(name) = 'apidb') d
WHERE LOWER('CdsLocation') NOT IN (SELECT LOWER(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

------------------------------------------------------------------------------
CREATE TABLE apidb.UtrLocation (
 utr_location_id              NUMBER(10),
 sequence_source_id           VARCHAR2(60),
 na_sequence_id               NUMBER(10),
 start_min                    NUMBER,
 end_max                      NUMBER,
 is_reversed                  NUMBER(1),
 direction                    NUMBER(1),
 parent_id                    NUMBER(10),
 is_top_level                 NUMBER(1),
 external_database_release_id NUMBER(10),
 modification_date            DATE,
 user_read                    NUMBER(1),
 user_write                   NUMBER(1),
 group_read                   NUMBER(1),
 group_write                  NUMBER(1),
 other_read                   NUMBER(1),
 other_write                  NUMBER(1),
 row_user_id                  NUMBER(12),
 row_group_id                 NUMBER(3),
 row_project_id               NUMBER(4),
 row_alg_invocation_id        NUMBER(12),
 FOREIGN KEY (na_sequence_id) REFERENCES dots.NaSequenceImp,
 FOREIGN KEY (parent_id) REFERENCES dots.NaFeatureImp (na_feature_id),
 FOREIGN KEY (external_database_release_id) REFERENCES sres.ExternalDatabaseRelease (external_database_release_id),
 FOREIGN KEY (row_alg_invocation_id) REFERENCES core.AlgorithmInvocation (algorithm_invocation_id),
 PRIMARY KEY (utr_location_id)
);

CREATE INDEX apidb.utrloc_ix1
ON apidb.UtrLocation (na_sequence_id, start_min, end_max, is_reversed,
                      parent_id)
TABLESPACE INDX;

CREATE INDEX apidb.utrloc_ix2
ON apidb.UtrLocation (parent_id, na_sequence_id, start_min, end_max,
                          is_reversed)
TABLESPACE INDX;

CREATE INDEX apidb.utrloc_revix1
ON apidb.UtrLocation (na_sequence_id, utr_location_id)
TABLESPACE INDX;

CREATE INDEX apidb.utrloc_revix3
ON apidb.UtrLocation (parent_id, utr_location_id)
TABLESPACE INDX;

CREATE INDEX apidb.utrloc_revix5
ON apidb.UtrLocation (external_database_release_id, utr_location_id)
TABLESPACE INDX;

CREATE INDEX apidb.utrloc_revix6
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
SELECT core.tableinfo_sq.nextval, 'UtrLocation',
       'Standard', 'utr_location_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE LOWER(name) = 'apidb') d
WHERE LOWER('UtrLocation') NOT IN (SELECT LOWER(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

------------------------------------------------------------------------------
CREATE TABLE apidb.IntronLocation (
 intron_location_id              NUMBER(10),
 sequence_source_id           VARCHAR2(60),
 na_sequence_id               NUMBER(10),
 start_min                    NUMBER,
 end_max                      NUMBER,
 is_reversed                  NUMBER(1),
 parent_id                    NUMBER(10),
 is_top_level                 NUMBER(1),
 external_database_release_id NUMBER(10),
 modification_date            DATE,
 user_read                    NUMBER(1),
 user_write                   NUMBER(1),
 group_read                   NUMBER(1),
 group_write                  NUMBER(1),
 other_read                   NUMBER(1),
 other_write                  NUMBER(1),
 row_user_id                  NUMBER(12),
 row_group_id                 NUMBER(3),
 row_project_id               NUMBER(4),
 row_alg_invocation_id        NUMBER(12),
 FOREIGN KEY (na_sequence_id) REFERENCES dots.NaSequenceImp,
 FOREIGN KEY (parent_id) REFERENCES dots.NaFeatureImp (na_feature_id),
 FOREIGN KEY (external_database_release_id) REFERENCES sres.ExternalDatabaseRelease (external_database_release_id),
 FOREIGN KEY (row_alg_invocation_id) REFERENCES core.AlgorithmInvocation (algorithm_invocation_id),
 PRIMARY KEY (intron_location_id)
);

CREATE INDEX apidb.intronloc_ix1
ON apidb.IntronLocation (na_sequence_id, start_min, end_max, is_reversed,
                      parent_id)
TABLESPACE INDX;

CREATE INDEX apidb.intronloc_ix2
ON apidb.IntronLocation (parent_id, na_sequence_id, start_min, end_max,
                          is_reversed)
TABLESPACE INDX;

CREATE INDEX apidb.intronloc_revix1
ON apidb.IntronLocation (na_sequence_id, intron_location_id)
TABLESPACE INDX;

CREATE INDEX apidb.intronloc_revix3
ON apidb.IntronLocation (parent_id, intron_location_id)
TABLESPACE INDX;

CREATE INDEX apidb.intronloc_revix5
ON apidb.IntronLocation (external_database_release_id, intron_location_id)
TABLESPACE INDX;

CREATE INDEX apidb.intronloc_revix6
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
SELECT core.tableinfo_sq.nextval, 'IntronLocation',
       'Standard', 'intron_location_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE LOWER(name) = 'apidb') d
WHERE LOWER('IntronLocation') NOT IN (SELECT LOWER(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

------------------------------------------------------------------------------
exit
