DROP VIEW dots.SnpFeature;

CREATE VIEW dots.SnpFeature AS
SELECT na_feature_id, na_sequence_id, subclass_view, name,
       sequence_ontology_id, parent_id, external_database_release_id,
       source_id, prediction_algorithm_id, is_predicted,
       review_status_id,
       string11 AS description, string2 AS reference_na,
       string3 AS reference_strain, string4 AS organism,
       number1 AS is_coding, number2 AS position_in_cds,
       string5 AS reference_aa, number6 AS position_in_protein,
       number3 AS has_nonsynonymous_allele, string6 AS major_allele,
       number4 AS major_allele_count, string7 AS major_product,
       string8 AS minor_allele, number5 AS minor_allele_count,
       string9 AS minor_product, string1 AS strains,
       string10 AS strains_revcomp,
       modification_date, user_read,
       user_write, group_read, group_write, other_read, other_write,
       row_user_id, row_group_id, row_project_id, row_alg_invocation_id
FROM dots.NaFeatureImp
WHERE subclass_view='SnpFeature';

GRANT INSERT, SELECT, UPDATE, DELETE ON dots.SnpFeature TO gus_w;
GRANT SELECT ON dots.SnpFeature TO gus_r;

------------------------------------------------------------------------------

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'SnpFeature',
       'Standard', 'na_feature_id',
       d.database_id, 0, 1, t.table_id, s.table_id, 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'dots') d,
     (SELECT table_id FROM core.TableInfo WHERE name = 'NAFeatureImp') t,
     (SELECT table_id FROM core.TableInfo WHERE name = 'NAFeature') s
WHERE 'SnpFeature' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);

------------------------------------------------------------------------------
exit;
