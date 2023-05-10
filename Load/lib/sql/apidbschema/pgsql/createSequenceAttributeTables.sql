------------------------------------------------------------------------------

CREATE TABLE ApiDB.AaSequenceAttribute (
  aa_sequence_attribute_id NUMERIC(10),
  aa_sequence_id NUMERIC(10),
  isoelectric_point DECIMAL(38,2),
  min_molecular_weight DECIMAL(38,2),
  max_molecular_weight DECIMAL(38,2),
  hydropathicity_gravy_score DECIMAL(38,2),
  aromaticity_score     DECIMAL(38,2),
  MODIFICATION_DATE     TIMESTAMP,
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

GRANT insert, select, update, delete ON ApiDB.AaSequenceAttribute TO gus_w;
GRANT select ON ApiDB.AaSequenceAttribute TO gus_r;
GRANT select ON ApiDB.AaSequenceAttribute_sq TO gus_w;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'AaSequenceAttribute',
       'Standard', 'aa_sequence_attribute_id',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM 
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'AaSequenceAttribute' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);

CREATE INDEX AaSeqAttr_revix
ON ApiDB.AaSequenceAttribute (aa_sequence_id, aa_sequence_attribute_id);

CREATE INDEX AaSeqAttr_iep_idx
ON apidb.AaSequenceAttribute (isoelectric_point, aa_sequence_attribute_id);

CREATE INDEX AaSeqAttr_minmolwt_idx
ON apidb.AaSequenceAttribute (min_molecular_weight, aa_sequence_attribute_id);

CREATE INDEX AaSeqAttr_maxmolwt_idx
ON apidb.AaSequenceAttribute (max_molecular_weight, aa_sequence_attribute_id);

CREATE INDEX asa_mod_ix
ON apidb.AaSequenceAttribute (modification_date, aa_sequence_attribute_id);

------------------------------------------------------------------------------

CREATE TABLE Apidb.NaSequenceAttribute (
  na_sequence_attribute_id NUMERIC(10),
  na_sequence_id           NUMERIC(10),
  volatility_score         DECIMAL(38,4),
  volatility_pmantissa     DECIMAL(38,3),
  volatility_pexponent     NUMERIC(4),
  karlins_delta            DECIMAL(38,3),
  effective_codon_number   DECIMAL(38,1),
  codon_bias_index         DECIMAL(38,2),
  codon_adaptation_index   DECIMAL(38,2),
  frequency_optimal_codons DECIMAL(38,2),
  synonymous_mutation_rate DECIMAL(38,2),
  nonsynonymous_mutation_rate DECIMAL(38,2),  
  MODIFICATION_DATE     TIMESTAMP,
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

GRANT insert, select, update, delete ON Apidb.NaSequenceAttribute TO gus_w;
GRANT select ON Apidb.NaSequenceAttribute TO gus_r;
GRANT select ON Apidb.NaSequenceAttribute_sq TO gus_w;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'NaSequenceAttribute',
       'Standard', 'na_sequence_attribute_id',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM 
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'NaSequenceAttribute' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);

------------------------------------------------------------------------------
