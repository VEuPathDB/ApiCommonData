CREATE TABLE dots.DbRefAaFeature
AS
SELECT db_ref_na_feature_id AS db_ref_aa_feature_id,
       na_feature_id AS aa_feature_id, db_ref_id, modification_date,
       user_read, user_write, group_read, group_write, other_read,
       other_write, row_user_id, row_group_id, row_project_id,
       row_alg_invocation_id
FROM dots.DbRefNaFeature
WHERE 1 = 0;


GRANT INSERT, SELECT, UPDATE, DELETE ON dots.DbRefAaFeature TO gus_w;
GRANT SELECT ON dots.DbRefAaFeature TO gus_r;

------------------------------------------------------------------------------

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'DbRefAaFeature',
       'Standard', 'db_ref_aa_feature_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'dots') d;

------------------------------------------------------------------------------
exit;
