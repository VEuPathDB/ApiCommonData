-- indexes on GUS tables

create index AaSeq_source_ix
  on dots.AaSequenceImp (lower(source_id));

create index NaFeat_alleles_ix
  on dots.NaFeatureImp (subclass_view, number4, number5, na_sequence_id, na_feature_id);

create index AaSequenceImp_string2_ix
  on dots.AaSequenceImp (string2, aa_sequence_id);
  
create index nasequenceimp_string1_seq_ix
  on dots.NaSequenceImp (string1, external_database_release_id, na_sequence_id);

create index nasequenceimp_string1_ix
  on dots.NaSequenceImp (string1, na_sequence_id);

create index ExonOrder_ix
  on dots.NaFeatureImp (subclass_view, parent_id, number3, na_feature_id); 

create index SeqvarStrain_ix
  on dots.NaFeatureImp (subclass_view, external_database_release_id, string9, na_feature_id); 

-- schema changes for GUS tables

-- can't do in in Pg without dropping/creating all the dependent views
--alter table dots.NaFeatureImp alter source_id type character varying(80);

ALTER TABLE dots.sequencePiece ADD COLUMN start_position NUMERIC(12), ADD COLUMN end_position NUMERIC(12);



