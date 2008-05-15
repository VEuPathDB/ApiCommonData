DROP VIEW dots.Transcript;

CREATE VIEW dots.Transcript AS
SELECT na_feature_id, na_sequence_id, subclass_view, name,
       sequence_ontology_id, parent_id, external_database_release_id,
       source_id, prediction_algorithm_id, is_predicted, review_status_id,
       string1 as citation, string2 as clone, string3 as codon,
       number1 as codon_start, string4 as cons_splice, string5 as ec_number,
       string6 as evidence, string7 as function, string8 as gene,
       string9 as label, string10 as map, string11 as num, string12 as partial,
       string13 as product, string14 as protein_id, string15 as pseudo,
       string16 as standard_name, clob1 as translation,
       string17 as transl_except, number2 as transl_table, string18 as usedin,
       number3 as is_partial, number4 as is_pseudo, string19 as anticodon,
       modification_date, user_read, user_write, group_read, group_write,
       other_read, other_write, row_user_id, row_group_id, row_project_id,
       row_alg_invocation_id
FROM dots.NaFeatureImp
WHERE subclass_view = 'Transcript';

GRANT SELECT ON dots.Transcript TO gus_r;
GRANT INSERT, UPDATE, DELETE ON dots.Transcript TO gus_w;

DROP VIEW dotsVer.TranscriptVer;

CREATE VIEW dotsVer.TranscriptVer AS
SELECT na_feature_id, na_sequence_id, subclass_view, name,
       sequence_ontology_id, parent_id, external_database_release_id,
       source_id, prediction_algorithm_id, is_predicted, review_status_id,
       string1 as citation, string2 as clone, string3 as codon,
       number1 as codon_start, string4 as cons_splice, string5 as ec_number,
       string6 as evidence, string7 as function, string8 as gene,
       string9 as label, string10 as map, string11 as num, string12 as partial,
       string13 as product, string14 as protein_id, string15 as pseudo,
       string16 as standard_name, clob1 as translation,
       string17 as transl_except, number2 as transl_table, string18 as usedin,
       number3 as is_partial, number4 as is_pseudo, string19 as anticodon,
       modification_date, user_read, user_write, group_read, group_write,
       other_read, other_write, row_user_id, row_group_id, row_project_id,
       row_alg_invocation_id,version_alg_invocation_id, version_date,
       version_transaction_id
FROM dotsVer.NaFeatureImpVer
WHERE subclass_view = 'Transcript';

GRANT SELECT ON dotsVer.TranscriptVer TO gus_r;
GRANT INSERT, UPDATE, DELETE ON dotsVer.TranscriptVer TO gus_w;

exit
