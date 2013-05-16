
CREATE TABLE ApiDB.AaSequenceAttribute (
  aa_sequence_attribute_id NUMERIC(10),
  aa_sequence_id NUMERIC(10),
  isoelectric_point DECIMAL(100,2),
  min_molecular_weight DECIMAL(100,2),
  max_molecular_weight DECIMAL(100,2),
  hydropathicity_gravy_score DECIMAL(100,2),
  aromaticity_score     DECIMAL(100,2),
  MODIFICATION_DATE     timestamp,
  USER_READ             NUMERIC(1),
  USER_WRITE            NUMERIC(1),
  GROUP_READ            NUMERIC(1),
  GROUP_WRITE           NUMERIC(1),
  OTHER_READ            NUMERIC(1),
  OTHER_WRITE           NUMERIC(1),
  ROW_USER_ID           NUMERIC(12),
  ROW_GROUP_ID          NUMERIC(3),
  ROW_PROJECT_ID        NUMERIC(4),
  ROW_ALG_INVOCATION_ID NUMERIC(12),
  FOREIGN KEY (aa_sequence_id) REFERENCES DoTS.AASequenceImp (aa_sequence_id),
  PRIMARY KEY (aa_sequence_attribute_id)
);

CREATE SEQUENCE ApiDB.AaSequenceAttribute_sq;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT nextval('core.tableinfo_sq'), 'AaSequenceAttribute',
       'Standard', 'aa_sequence_attribute_id',
       (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb'), 0, 0, NULL, NULL, 
       1,current_timestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo), 0
WHERE lower('AaSequenceAttribute') NOT IN (SELECT lower(name) FROM core.TableInfo
        WHERE database_id = (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb'));



CREATE INDEX AaSeqAttr_revix
ON ApiDB.AaSequenceAttribute (aa_sequence_id, aa_sequence_attribute_id);

CREATE INDEX AaSeqAttr_iep_idx
ON apidb.AaSequenceAttribute (isoelectric_point, aa_sequence_attribute_id);

CREATE INDEX AaSeqAttr_minmolwt_idx
ON apidb.AaSequenceAttribute (min_molecular_weight, aa_sequence_attribute_id);

CREATE INDEX AaSeqAttr_maxmolwt_idx
ON apidb.AaSequenceAttribute (max_molecular_weight, aa_sequence_attribute_id);

CREATE INDEX apidb.asa_mod_ix
ON apidb.AaSequenceAttribute (modification_date, aa_sequence_attribute_id);

------------------------------------------------------------------------------

CREATE TABLE Apidb.NaSequenceAttribute (
  na_sequence_attribute_id NUMERIC(10),
  na_sequence_id           NUMERIC(10),
  volatility_score         DECIMAL(100,4),
  volatility_pmantissa     DECIMAL(100,3),
  volatility_pexponent     NUMERIC(4),
  karlins_delta            DECIMAL(100,3),
  effective_codon_NUMERIC   DECIMAL(100,1),
  codon_bias_index         DECIMAL(100,2),
  codon_adaptation_index   DECIMAL(100,2),
  frequency_optimal_codons DECIMAL(100,2),
  synonymous_mutation_rate DECIMAL(100,2),
  nonsynonymous_mutation_rate DECIMAL(100,2),  
  MODIFICATION_DATE     timestamp,
  USER_READ             NUMERIC(1),
  USER_WRITE            NUMERIC(1),
  GROUP_READ            NUMERIC(1),
  GROUP_WRITE           NUMERIC(1),
  OTHER_READ            NUMERIC(1),
  OTHER_WRITE           NUMERIC(1),
  ROW_USER_ID           NUMERIC(12),
  ROW_GROUP_ID          NUMERIC(3),
  ROW_PROJECT_ID        NUMERIC(4),
  ROW_ALG_INVOCATION_ID NUMERIC(12),
  FOREIGN KEY (na_sequence_id) REFERENCES DoTS.NASequenceImp (na_sequence_id),
  PRIMARY KEY (na_sequence_attribute_id)
);

CREATE INDEX NaSeqAttr_revix
ON Apidb.NaSequenceAttribute (na_sequence_id, na_sequence_attribute_id);

CREATE SEQUENCE Apidb.NaSequenceAttribute_sq;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT nextval('core.tableinfo_sq'), 'NaSequenceAttribute',
       'Standard', 'na_sequence_attribute_id',
       (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb'), 0, 0, NULL, NULL, 
       1,current_timestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo), 0
WHERE lower('NaSequenceAttribute') NOT IN (SELECT lower(name) FROM core.TableInfo
        WHERE database_id = (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb'));



------------------------------------------------------------------------------

