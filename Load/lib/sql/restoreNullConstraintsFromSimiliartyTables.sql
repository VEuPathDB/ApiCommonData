
ALTER TABLE DoTS.Similarity MODIFY total_match_length NOT NULL;
ALTER TABLE DoTS.Similarity MODIFY number_identical NOT NULL;
ALTER TABLE DoTS.Similarity MODIFY number_positive NOT NULL;
ALTER TABLE DoTS.Similarity MODIFY score NOT NULL;
ALTER TABLE DoTS.Similarity MODIFY pvalue_mant NOT NULL;
ALTER TABLE DoTS.Similarity MODIFY pvalue_exp NOT NULL;

ALTER TABLE DoTS.SimilaritySpan MODIFY match_length NOT NULL;
ALTER TABLE DoTS.SimilaritySpan MODIFY number_identical NOT NULL;
ALTER TABLE DoTS.SimilaritySpan MODIFY number_positive NOT NULL;
ALTER TABLE DoTS.SimilaritySpan MODIFY score NOT NULL;
ALTER TABLE DoTS.SimilaritySpan MODIFY pvalue_mant NOT NULL;
ALTER TABLE DoTS.SimilaritySpan MODIFY pvalue_exp NOT NULL;
