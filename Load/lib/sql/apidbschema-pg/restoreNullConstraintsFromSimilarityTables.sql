
ALTER TABLE DoTS.Similarity MODIFY total_match_length NOT NULL;
ALTER TABLE DoTS.Similarity MODIFY NUMERIC_identical NOT NULL;
ALTER TABLE DoTS.Similarity MODIFY NUMERIC_positive NOT NULL;
ALTER TABLE DoTS.Similarity MODIFY score NOT NULL;
ALTER TABLE DoTS.Similarity MODIFY pvalue_mant NOT NULL;
ALTER TABLE DoTS.Similarity MODIFY pvalue_exp NOT NULL;

ALTER TABLE DoTS.SimilaritySpan MODIFY match_length NOT NULL;
ALTER TABLE DoTS.SimilaritySpan MODIFY NUMERIC_identical NOT NULL;
ALTER TABLE DoTS.SimilaritySpan MODIFY NUMERIC_positive NOT NULL;
ALTER TABLE DoTS.SimilaritySpan MODIFY score NOT NULL;
ALTER TABLE DoTS.SimilaritySpan MODIFY pvalue_mant NOT NULL;
ALTER TABLE DoTS.SimilaritySpan MODIFY pvalue_exp NOT NULL;

ALTER TABLE DoTSVer.SimilarityVer MODIFY total_match_length NOT NULL;
ALTER TABLE DoTSVer.SimilarityVer MODIFY NUMERIC_identical NOT NULL;
ALTER TABLE DoTSVer.SimilarityVer MODIFY NUMERIC_positive NOT NULL;
ALTER TABLE DoTSVer.SimilarityVer MODIFY score NOT NULL;
ALTER TABLE DoTSVer.SimilarityVer MODIFY pvalue_mant NOT NULL;
ALTER TABLE DoTSVer.SimilarityVer MODIFY pvalue_exp NOT NULL;

ALTER TABLE DoTSVer.SimilaritySpanVer MODIFY match_length NOT NULL;
ALTER TABLE DoTSVer.SimilaritySpanVer MODIFY NUMERIC_identical NOT NULL;
ALTER TABLE DoTSVer.SimilaritySpanVer MODIFY NUMERIC_positive NOT NULL;
ALTER TABLE DoTSVer.SimilaritySpanVer MODIFY score NOT NULL;
ALTER TABLE DoTSVer.SimilaritySpanVer MODIFY pvalue_mant NOT NULL;
ALTER TABLE DoTSVer.SimilaritySpanVer MODIFY pvalue_exp NOT NULL;

exit
