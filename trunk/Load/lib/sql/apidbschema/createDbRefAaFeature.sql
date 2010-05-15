CREATE TABLE dots.DbRefAaFeature
AS
SELECT db_ref_na_feature_id AS db_ref_aa_feature_id,
       na_feature_id AS aa_feature_id, db_ref_id, modification_date,
       user_read, user_write, group_read, group_write, other_read,
       other_write, row_user_id, row_group_id, row_project_id,
       row_alg_invocation_id
FROM dots.DbRefNaFeature
WHERE 1 = 0;

ALTER TABLE dots.DbRefAaFeature
ADD CONSTRAINT draf_pk PRIMARY KEY (db_ref_aa_feature_id);

ALTER TABLE dots.DbRefAaFeature
ADD CONSTRAINT draf_fk1 FOREIGN KEY (aa_feature_id)
REFERENCES dots.AaFeatureImp (aa_feature_id);

ALTER TABLE dots.DbRefAaFeature
ADD CONSTRAINT draf_fk2 FOREIGN KEY (db_ref_id)
REFERENCES sres.DbRef (db_ref_id);

CREATE SEQUENCE dots.DbRefAaFeature_sq;

GRANT SELECT ON dots.DbRefAaFeature_sq TO gus_w;

CREATE INDEX dots.draf_ind1
ON dots.DbRefAaFeature (db_ref_id, db_ref_aa_feature_id);

CREATE INDEX dots.draf_ind2
ON dots.DbRefAaFeature (aa_feature_id, db_ref_id);

GRANT INSERT, SELECT, UPDATE, DELETE ON dots.DbRefAaFeature TO gus_w;
GRANT SELECT ON dots.DbRefAaFeature TO gus_r;

------------------------------------------------------------------------------

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'DbRefAAFeature',
       'Standard', 'db_ref_aa_feature_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'dots') d
WHERE 'DbRefAAFeature' NOT IN (SELECT name FROM core.TableInfo
                                    WHERE database_id = d.database_id);

------------------------------------------------------------------------------
exit;
