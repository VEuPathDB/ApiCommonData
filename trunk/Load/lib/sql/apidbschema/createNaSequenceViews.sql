DROP VIEW dots.VirtualSequence;

CREATE VIEW dots.VirtualSequence AS
SELECT na_sequence_id, sequence_version, subclass_view, sequence_type_id,
       sequence_ontology_id, taxon_id, sequence, length, a_count, c_count,
       g_count, t_count, other_count, description, external_database_release_id,
       source_na_sequence_id, sequence_piece_id, sequencing_center_contact_id,
       string1 AS source_id, string2 AS confidence,
       string3 AS secondary_identifier, string4 AS chromosome,
       number1 AS chromosome_order_num, modification_date, user_read,
       user_write, group_read, group_write, other_read, other_write,
       row_user_id, row_group_id, row_project_id, row_alg_invocation_id
FROM dots.NaSequenceImp
WHERE subclass_view='VirtualSequence';

GRANT SELECT ON dots.VirtualSequence TO gus_r;
GRANT INSERT, UPDATE, DELETE ON dots.VirtualSequence TO gus_w;

------------------------------
DROP VIEW dotsVer.VirtualSequenceVer;

CREATE VIEW dotsVer.VirtualSequenceVer AS
SELECT na_sequence_id, sequence_version, subclass_view, sequence_type_id,
       sequence_ontology_id, taxon_id, sequence, length, a_count, c_count,
       g_count, t_count, other_count, description, external_database_release_id,
       source_na_sequence_id, sequence_piece_id, sequencing_center_contact_id,
       string1 AS source_id, string2 AS confidence,
       string3 AS secondary_identifier, string4 AS chromosome,
       number1 AS chromosome_order_num, modification_date, user_read,
       user_write, group_read, group_write, other_read, other_write,
       row_user_id, row_group_id, row_project_id, row_alg_invocation_id,
       version_alg_invocation_id, version_date, version_transaction_id 
FROM dotsVer.NaSequenceImpVer
WHERE subclass_view='VirtualSequence';

GRANT SELECT ON dotsVer.VirtualSequenceVer TO gus_r;
GRANT INSERT, UPDATE, DELETE ON dotsVer.VirtualSequenceVer TO gus_w;
------------------------------
DROP VIEW dots.NaSequence;

CREATE VIEW dots.NaSequence AS
SELECT na_sequence_id, sequence_version, subclass_view, sequence_type_id,
       sequence_ontology_id, taxon_id, sequence, length, a_count, c_count,
       g_count, t_count, other_count, description, external_database_release_id,
       source_na_sequence_id, sequence_piece_id, sequencing_center_contact_id,
       string1 AS source_id, modification_date, user_read, user_write,
       group_read, group_write, other_read, other_write, row_user_id,
       row_group_id, row_project_id, row_alg_invocation_id
FROM dots.NaSequenceImp;

GRANT SELECT ON dots.NaSequence TO gus_r;
GRANT INSERT, UPDATE, DELETE ON dots.NaSequence TO gus_w;

------------------------------
DROP VIEW dotsVer.NaSequenceVer;

CREATE VIEW dotsVer.NaSequenceVer AS
SELECT na_sequence_id, sequence_version, subclass_view, sequence_type_id,
       sequence_ontology_id, taxon_id, sequence, length, a_count, c_count,
       g_count, t_count, other_count, description, external_database_release_id,
       source_na_sequence_id, sequence_piece_id, sequencing_center_contact_id,
       string1 AS source_id, modification_date, user_read, user_write,
       group_read, group_write, other_read, other_write, row_user_id,
       row_group_id, row_project_id, row_alg_invocation_id,
       version_alg_invocation_id, version_date, version_transaction_id 
FROM dotsVer.NaSequenceImpVer;

GRANT SELECT ON dotsVer.NaSequenceVer TO gus_r;
GRANT INSERT, UPDATE, DELETE ON dotsVer.NaSequenceVer TO gus_w;

------------------------------

DROP VIEW dots.Assembly;

CREATE VIEW dots.Assembly AS
SELECT na_sequence_id, sequence_version, subclass_view, sequence_type_id,
       sequence_ontology_id, taxon_id, sequence, length, a_count, c_count,
       g_count, t_count,other_count, description, external_database_release_id,
       source_na_sequence_id, sequence_piece_id, sequencing_center_contact_id,
       number1 AS full_length_cds, number2 AS assembly_consistency,
       number3 AS contains_mrna, number4 AS number_of_contained_sequences,
       string1 AS source_id, string2 AS notes, clob1 AS gapped_consensus,
       clob2 AS quality_values, modification_date, user_read, user_write,
       group_read, group_write, other_read, other_write, row_user_id,
       row_group_id, row_project_id, row_alg_invocation_id
FROM dots.NaSequenceImp
WHERE subclass_view='Assembly';

GRANT SELECT ON dots.Assembly TO gus_r;
GRANT INSERT, UPDATE, DELETE ON dots.Assembly TO gus_w;

------------------------------

DROP VIEW dotsVer.AssemblyVer;

CREATE VIEW dotsVer.AssemblyVer AS
SELECT na_sequence_id, sequence_version, subclass_view, sequence_type_id,
       sequence_ontology_id, taxon_id, sequence, length, a_count, c_count,
       g_count, t_count,other_count, description, external_database_release_id,
       source_na_sequence_id, sequence_piece_id, sequencing_center_contact_id,
       number1 AS full_length_cds, number2 AS assembly_consistency,
       number3 AS contains_mrna, number4 AS number_of_contained_sequences,
       string1 AS source_id, string2 AS notes, clob1 AS gapped_consensus,
       clob2 AS quality_values, modification_date, user_read, user_write,
       group_read, group_write, other_read, other_write, row_user_id,
       row_group_id, row_project_id, row_alg_invocation_id,
       version_alg_invocation_id, version_date, version_transaction_id 
FROM dotsVer.NaSequenceImpVer
WHERE subclass_view='Assembly';

GRANT SELECT ON dotsVer.AssemblyVer TO gus_r;
GRANT INSERT, UPDATE, DELETE ON dotsVer.AssemblyVer TO gus_w;

------------------------------

exit
