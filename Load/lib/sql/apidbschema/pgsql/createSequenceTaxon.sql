CREATE TABLE apidb.TaxonString (
 taxon_string_id              NUMERIC(10) ,
 taxon_id                     NUMERIC(10),
 taxon_string                 VARCHAR(300),
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
 FOREIGN KEY (taxon_id) REFERENCES sres.Taxon,
 PRIMARY KEY (taxon_string_id)
);

CREATE SEQUENCE apidb.TaxonString_sq;

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.TaxonString TO gus_w;
GRANT SELECT ON apidb.TaxonString TO gus_r;
GRANT SELECT ON apidb.TaxonString_sq TO gus_w;

CREATE INDEX tx_ix
  ON apidb.TaxonString (taxon_id, taxon_string_id)
  TABLESPACE indx;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable,
     modification_date, user_read, user_write, group_read, group_write,
     other_read, other_write, row_user_id, row_group_id, row_project_id,
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'TaxonString',
       'Standard', 'taxon_string_id',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE LOWER('TaxonString') NOT IN (SELECT lower(name) FROM core.TableInfo
                                     WHERE database_id = d.database_id);

----------------------------------------------------------------------

CREATE TABLE apidb.SequenceTaxonString (
 sequence_taxon_string_id     NUMERIC(10) ,
 na_sequence_id               NUMERIC(10),
 taxon_string_id              NUMERIC(10),
 external_database_release_id NUMERIC(10) NOT NULL,
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
 FOREIGN KEY (taxon_string_id) REFERENCES apidb.TaxonString,
 FOREIGN KEY (external_database_release_id) REFERENCES sres.ExternalDatabaseRelease,
 PRIMARY KEY (sequence_taxon_string_id)
);

CREATE SEQUENCE apidb.SequenceTaxonString_sq;

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.SequenceTaxonString TO gus_w;
GRANT SELECT ON apidb.SequenceTaxonString TO gus_r;
GRANT SELECT ON apidb.SequenceTaxonString_sq TO gus_w;

CREATE INDEX seqTxStr_seq_ix
  ON apidb.SequenceTaxonString (na_sequence_id, taxon_string_id, external_database_release_id)
  TABLESPACE indx;

CREATE INDEX seqTxStr_tx_ix
  ON apidb.SequenceTaxonString (taxon_string_id, na_sequence_id, external_database_release_id)
  TABLESPACE indx;

CREATE INDEX seqTxStr_dbrls_ix
  ON apidb.SequenceTaxonString (external_database_release_id, na_sequence_id, taxon_string_id)
  TABLESPACE indx;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable,
     modification_date, user_read, user_write, group_read, group_write,
     other_read, other_write, row_user_id, row_group_id, row_project_id,
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'SequenceTaxonString',
       'Standard', 'sequence_taxon_string_id',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE LOWER('SequenceTaxonString') NOT IN (SELECT lower(name) FROM core.TableInfo
                                     WHERE database_id = d.database_id);
 
------------------------------------------------------------------------------
