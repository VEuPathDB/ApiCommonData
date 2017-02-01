CREATE TABLE apidb.SequenceTaxon (
 sequence_taxon_id            NUMBER(10) ,
 na_sequence_id               NUMBER(10),
 taxon_id                     NUMBER(10),
 external_database_release_id NUMBER(10) NOT NULL,
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
 FOREIGN KEY (taxon_id) REFERENCES sres.Taxon,
 FOREIGN KEY (external_database_release_id) REFERENCES sres.ExternalDatabaseRelease,
 PRIMARY KEY (sequence_taxon_id)
);

CREATE SEQUENCE apidb.SequenceTaxon_sq;

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.SequenceTaxon TO gus_w;
GRANT SELECT ON apidb.SequenceTaxon TO gus_r;
GRANT SELECT ON apidb.SequenceTaxon_sq TO gus_w;

CREATE INDEX apidb.seqTx_seq_ix
  ON apidb.SequenceTaxon (na_sequence_id, taxon_id, external_database_release_id)
  TABLESPACE indx;

CREATE INDEX apidb.seqTx_tx_ix
  ON apidb.SequenceTaxon (taxon_id, na_sequence_id, external_database_release_id)
  TABLESPACE indx;

CREATE INDEX apidb.seqTx_dbrls_ix
  ON apidb.SequenceTaxon (external_database_release_id, na_sequence_id, taxon_id)
  TABLESPACE indx;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable,
     modification_date, user_read, user_write, group_read, group_write,
     other_read, other_write, row_user_id, row_group_id, row_project_id,
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'SequenceTaxon',
       'Standard', 'sequence_taxon_id',
       d.database_id, 0, 0, '', '', 1, sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE LOWER('SequenceTaxon') NOT IN (SELECT lower(name) FROM core.TableInfo
                                     WHERE database_id = d.database_id);
 
------------------------------------------------------------------------------
exit;
