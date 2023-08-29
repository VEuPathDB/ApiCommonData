
ALTER TABLE DoTS.Similarity ALTER COLUMN total_match_length SET NOT NULL;
ALTER TABLE DoTS.Similarity ALTER COLUMN number_identical SET NOT NULL;
ALTER TABLE DoTS.Similarity ALTER COLUMN number_positive SET NOT NULL;
ALTER TABLE DoTS.Similarity ALTER COLUMN score SET NOT NULL;
ALTER TABLE DoTS.Similarity ALTER COLUMN pvalue_mant SET NOT NULL;
ALTER TABLE DoTS.Similarity ALTER COLUMN pvalue_exp SET NOT NULL;

ALTER TABLE DoTS.SimilaritySpan ALTER COLUMN match_length SET NOT NULL;
ALTER TABLE DoTS.SimilaritySpan ALTER COLUMN number_identical SET NOT NULL;
ALTER TABLE DoTS.SimilaritySpan ALTER COLUMN number_positive SET NOT NULL;
ALTER TABLE DoTS.SimilaritySpan ALTER COLUMN score SET NOT NULL;
ALTER TABLE DoTS.SimilaritySpan ALTER COLUMN pvalue_mant SET NOT NULL;
ALTER TABLE DoTS.SimilaritySpan ALTER COLUMN pvalue_exp SET NOT NULL;

ALTER TABLE DoTSVer.SimilarityVer ALTER COLUMN total_match_length SET NOT NULL;
ALTER TABLE DoTSVer.SimilarityVer ALTER COLUMN number_identical SET NOT NULL;
ALTER TABLE DoTSVer.SimilarityVer ALTER COLUMN number_positive SET NOT NULL;
ALTER TABLE DoTSVer.SimilarityVer ALTER COLUMN score SET NOT NULL;
ALTER TABLE DoTSVer.SimilarityVer ALTER COLUMN pvalue_mant SET NOT NULL;
ALTER TABLE DoTSVer.SimilarityVer ALTER COLUMN pvalue_exp SET NOT NULL;

ALTER TABLE DoTSVer.SimilaritySpanVer ALTER COLUMN match_length SET NOT NULL;
ALTER TABLE DoTSVer.SimilaritySpanVer ALTER COLUMN number_identical SET NOT NULL;
ALTER TABLE DoTSVer.SimilaritySpanVer ALTER COLUMN number_positive SET NOT NULL;
ALTER TABLE DoTSVer.SimilaritySpanVer ALTER COLUMN score SET NOT NULL;
ALTER TABLE DoTSVer.SimilaritySpanVer ALTER COLUMN pvalue_mant SET NOT NULL;
ALTER TABLE DoTSVer.SimilaritySpanVer ALTER COLUMN pvalue_exp SET NOT NULL;
