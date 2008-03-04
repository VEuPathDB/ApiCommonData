
-- indexes to tune GUS

CREATE INDEX dots.NaFeat_SubclassParent_ix
ON dots.NaFeatureImp (subclass_view, parent_id, na_feature_id);

CREATE INDEX dots.NaFeat_SubclassIds_ix
ON dots.NaFeatureImp (subclass_view, source_id, na_feature_id, na_sequence_id);

CREATE INDEX dots.aafeat_subclassparent_ix
ON dots.AaFeatureImp (subclass_view, parent_id, aa_feature_id);

CREATE INDEX aafeature_subclasssource_ix
ON dots.AaFeatureImp (subclass_view, source_id, aa_feature_id); 

CREATE INDEX dots.aaseq_subclassdbrel_ix
ON dots.AaSequenceImp (external_database_release_id, subclass_view,
                      aa_sequence_id);

CREATE INDEX dots.NaFeat_alleles_ix
ON dots.NaFeatureImp (subclass_view, number4, number5, na_sequence_id,
                     na_feature_id);

CREATE INDEX dots.AaSequenceImp_string2_ix
ON dots.AaSequenceImp (string2, aa_sequence_id);

CREATE INDEX dots.AaSequenceImp_classtax_ix
ON dots.AaSequenceImp (subclass_view, taxon_id, aa_sequence_id);

CREATE INDEX dots.NaFeat_SubclassSource_ix
ON dots.NaFeatureImp (subclass_view, source_id);

CREATE INDEX dots.loc_feat_ix
       ON dots.NaLocation (na_feature_id, start_min, end_max, is_reversed);

CREATE INDEX dots.sim_pval_ix
       ON dots.Similarity (query_id, pvalue_exp, pvalue_mant, subject_id);
-------------------------------------------------------------------------------

-- GUS table shortcomings

ALTER TABLE core.AlgorithmParam MODIFY (string_value VARCHAR2(2000));

ALTER TABLE sres.DbRef MODIFY (secondary_identifier varchar2(100));

exit
