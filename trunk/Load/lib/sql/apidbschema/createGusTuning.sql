-- indexes on GUS tables

create index dots.AaSeq_source_ix
  on dots.AaSequenceImp (lower(source_id)) tablespace INDX;

create index dots.aaseq_subclassdbrel_ix
  on dots.AaSequenceImp (external_database_release_id, subclass_view, aa_sequence_id)
  tablespace INDX;

create index dots.NaFeat_alleles_ix
  on dots.NaFeatureImp (subclass_view, number4, number5, na_sequence_id, na_feature_id)
  tablespace INDX;

create index dots.AaSequenceImp_string2_ix
  on dots.AaSequenceImp (string2, aa_sequence_id)
  tablespace INDX;

create index dots.AaSequenceImp_class_tax_ix
  on dots.AaSequenceImp (subclass_view, taxon_id, aa_sequence_id)
  tablespace INDX;

create index dots.NaFeat_SubclassIds_ix
  on dots.NaFeatureImp (subclass_view, source_id, na_feature_id, na_sequence_id)
  tablespace INDX;

create index dots.NaFeat_SubclassParent_ix
  on dots.NaFeatureImp (subclass_view, parent_id, na_feature_id)
  tablespace INDX;

create index dots.loc_feat_ix
  on dots.NaLocation (na_feature_id, start_min, end_max, is_reversed)
  tablespace INDX;

create index dots.sim_pval_ix
  on dots.Similarity (query_id, pvalue_exp, pvalue_mant, subject_id)
  tablespace INDX;

create index dots.nasequenceimp_string1_seq_idx
  on dots.NaSequenceImp (string1, external_database_release_id, na_sequence_id)
  tablespace INDX;

create index dots.nasequenceimp_string1_idx
  on dots.NaSequenceImp (string1, na_sequence_id)
  tablespace INDX;

create index dots.aafeat_subclassparent_ix
  on dots.AaFeatureImp (subclass_view, parent_id, aa_feature_id)
  tablespace INDX;

create index aafeature_subclasssource_ix
  on dots.AaFeatureImp (subclass_view, source_id, aa_feature_id)
  tablespace INDX; 

create index AnalRes_subclassRow_ix
  on rad.AnalysisResultImp (subclass_view, row_id)
  tablespace INDX; 

create index ExonOrder_ix
  on dots.NaFeatureImp (subclass_view, parent_id, number3, na_feature_id)
   tablespace INDX; 

create index sres.so_term_ix
  on sres.SequenceOntology (term_name, sequence_ontology_id)
  tablespace INDX; 

-- GUS table shortcomings

ALTER TABLE core.AlgorithmParam MODIFY (string_value VARCHAR2(2000));
ALTER TABLE coreVer.AlgorithmParamVer MODIFY (string_value VARCHAR2(2000));

ALTER TABLE sres.DbRef MODIFY (secondary_identifier varchar2(100));
ALTER TABLE sresVer.DbRefVer MODIFY (secondary_identifier varchar2(100));

ALTER TABLE sres.GoSynonym MODIFY (text VARCHAR2(1000));
ALTER TABLE sresVer.GoSynonymVer MODIFY (text VARCHAR2(1000));

ALTER TABLE sres.GoEvidenceCode       MODIFY (description VARCHAR2(1500));
ALTER TABLE sresVer.GoEvidenceCodeVer MODIFY (description VARCHAR2(1500));
ALTER TABLE sres.GoEvidenceCode       MODIFY (name VARCHAR2(5));
ALTER TABLE sresVer.GoEvidenceCodeVer MODIFY (name VARCHAR2(5)); 

ALTER TABLE rad.Analysis ADD name VARCHAR2(200);
ALTER TABLE radVer.AnalysisVer ADD name VARCHAR2(200);

-- Make manufacturer_id and technology_type_id nullable
alter table rad.arraydesign modify (MANUFACTURER_ID NUMBER(12) null, 
                                    TECHNOLOGY_TYPE_ID NUMBER(10) null);


exit
