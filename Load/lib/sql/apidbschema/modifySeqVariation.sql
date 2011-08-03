DROP VIEW dots.SeqVariation;

CREATE VIEW dots.SeqVariation AS
SELECT na_feature_id, na_sequence_id, subclass_view, name, sequence_ontology_id,
       parent_id, external_database_release_id, source_id,
       prediction_algorithm_id, is_predicted, review_status_id,
       string1 AS citation, string2 AS clone, string3 AS evidence,
       string4 AS function, string5 AS gene, string6 AS label, string7 AS map,
       string8 AS organism, string9 AS strain, string10 AS partial,
       string11 AS phenotype, string12 AS product, string13 AS standard_name,
       string14 AS substitute, string15 AS num, string16 AS usedin,
       string17 AS mod_base, number1 AS is_partial, float1 AS frequency,
       string18 AS allele, number2 AS matches_reference,
       number3 as coverage, float2 as allele_percent, float3 as pvalue,
       number4 as quality,
       modification_date, user_read, user_write, group_read, group_write,
       other_read, other_write, row_user_id, row_group_id, row_project_id,
       row_alg_invocation_id
FROM dots.NaFeatureImp
WHERE subclass_view='SeqVariation';

GRANT SELECT ON dots.SeqVariation TO gus_r;

GRANT INSERT, UPDATE, DELETE ON dots.SeqVariation TO gus_w;

exit
