
ALTER TABLE DoTS.Similarity MODIFY total_match_length NULL;
ALTER TABLE DoTS.Similarity MODIFY number_identical NULL;
ALTER TABLE DoTS.Similarity MODIFY number_positive NULL;
ALTER TABLE DoTS.Similarity MODIFY score NULL;
ALTER TABLE DoTS.Similarity MODIFY pvalue_mant NULL;
ALTER TABLE DoTS.Similarity MODIFY pvalue_exp NULL;

ALTER TABLE DoTS.SimilaritySpan MODIFY match_length NULL;
ALTER TABLE DoTS.SimilaritySpan MODIFY number_identical NULL;
ALTER TABLE DoTS.SimilaritySpan MODIFY number_positive NULL;
ALTER TABLE DoTS.SimilaritySpan MODIFY score NULL;
ALTER TABLE DoTS.SimilaritySpan MODIFY pvalue_mant NULL;
ALTER TABLE DoTS.SimilaritySpan MODIFY pvalue_exp NULL;

ALTER TABLE DoTSVer.SimilarityVer MODIFY total_match_length NULL;
ALTER TABLE DoTSVer.SimilarityVer MODIFY number_identical NULL;
ALTER TABLE DoTSVer.SimilarityVer MODIFY number_positive NULL;
ALTER TABLE DoTSVer.SimilarityVer MODIFY score NULL;
ALTER TABLE DoTSVer.SimilarityVer MODIFY pvalue_mant NULL;
ALTER TABLE DoTSVer.SimilarityVer MODIFY pvalue_exp NULL;

ALTER TABLE DoTSVer.SimilaritySpanVer MODIFY match_length NULL;
ALTER TABLE DoTSVer.SimilaritySpanVer MODIFY number_identical NULL;
ALTER TABLE DoTSVer.SimilaritySpanVer MODIFY number_positive NULL;
ALTER TABLE DoTSVer.SimilaritySpanVer MODIFY score NULL;
ALTER TABLE DoTSVer.SimilaritySpanVer MODIFY pvalue_mant NULL;
ALTER TABLE DoTSVer.SimilaritySpanVer MODIFY pvalue_exp NULL;

exit
