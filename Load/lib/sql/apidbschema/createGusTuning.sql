-- indexes on GUS tables

create index dots.AaSeq_source_ix
  on dots.AaSequenceImp (lower(source_id)) tablespace INDX;

create index dots.NaFeat_alleles_ix
  on dots.NaFeatureImp (subclass_view, number4, number5, na_sequence_id, na_feature_id)
  tablespace INDX;

create index dots.AaSequenceImp_string2_ix
  on dots.AaSequenceImp (string2, aa_sequence_id)
  tablespace INDX;

create index dots.nasequenceimp_string1_seq_idx
  on dots.NaSequenceImp (string1, external_database_release_id, na_sequence_id)
  tablespace INDX;

create index dots.nasequenceimp_string1_idx
  on dots.NaSequenceImp (string1, na_sequence_id)
  tablespace INDX;

create index ExonOrder_ix
  on dots.NaFeatureImp (subclass_view, parent_id, number3, na_feature_id)
   tablespace INDX; 

-- schema changes for GUS tables

alter table dots.NaFeatureImp modify (source_id varchar2(80));

ALTER TABLE dots.sequencePiece ADD ( start_position number(12), end_position number(12) );

exit
