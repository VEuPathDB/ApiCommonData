GRANT references ON DoTS.NaSequenceImp TO ApiDB;
GRANT references ON DoTS.AaSequenceImp TO ApiDB;
------------------------------------------------------------------------------

CREATE TABLE ApiDB.AaSequenceAttribute (
  aa_sequence_attribute_id NUMBER(10),
  aa_sequence_id NUMBER(10),
  isoelectric_point DECIMAL(*,2),
  min_molecular_weight DECIMAL(*,2),
  max_molecular_weight DECIMAL(*,2),
  hydropathicity_gravy_score DECIMAL(*,2),
  aromaticity_score     DECIMAL(*,2),
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
SELECT core.tableinfo_sq.nextval, 'AaSequenceAttribute',
       'Standard', 'aa_sequence_attribute_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'AaSequenceAttribute' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);

CREATE INDEX apidb.AaSeqAttr_iep_idx
ON apidb.AaSequenceAttribute (isoelectric_point, aa_sequence_attribute_id);

CREATE INDEX apidb.AaSeqAttr_minmolwt_idx
ON apidb.AaSequenceAttribute (min_molecular_weight, aa_sequence_attribute_id);

CREATE INDEX apidb.AaSeqAttr_maxmolwt_idx
ON apidb.AaSequenceAttribute (max_molecular_weight, aa_sequence_attribute_id);

------------------------------------------------------------------------------

CREATE TABLE ApiDB.NaSequenceAttribute (
  na_sequence_attribute_id NUMBER(10),
  na_sequence_id           NUMBER(10),
  volatility_score         DECIMAL(*,4),
  volatility_pmantissa     DECIMAL(*,3),
  volatility_pexponent     NUMBER(4),
  karlins_delta            DECIMAL(*,3),
  effective_codon_number   DECIMAL(*,1),
  codon_bias_index         DECIMAL(*,2),
  codon_adaptation_index   DECIMAL(*,2),
  frequency_optimal_codons DECIMAL(*,2),
  synonymous_mutation_rate DECIMAL(*,2),
  nonsynonymous_mutation_rate DECIMAL(*,2),  
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
  FOREIGN KEY (na_sequence_id) REFERENCES DoTS.NASequenceImp (na_sequence_id),
  PRIMARY KEY (na_sequence_attribute_id)
);

CREATE SEQUENCE ApiDB.NaSequenceAttribute_sq;

GRANT insert, select, update, delete ON ApiDB.NaSequenceAttribute TO gus_w;
GRANT select ON ApiDB.NaSequenceAttribute TO gus_r;
GRANT select ON ApiDB.NaSequenceAttribute_sq TO gus_w;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'NaSequenceAttribute',
       'Standard', 'na_sequence_attribute_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'NaSequenceAttribute' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);

------------------------------------------------------------------------------

exit;
