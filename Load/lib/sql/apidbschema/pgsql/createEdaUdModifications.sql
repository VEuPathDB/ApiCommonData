-- set CONCAT OFF;

ALTER TABLE ApidbUserDatasets.study ADD COLUMN user_dataset_id NUMERIC(20);

ALTER TABLE ApidbUserDatasets.study ADD CONSTRAINT edastd_fk FOREIGN KEY (user_dataset_id)
    REFERENCES apidbUserDatasets.InstalledUserDataset;


CREATE TABLE ApidbUserDatasets.DatasetAttributes (
 dataset_id NUMERIC(12) NOT NULL,
 user_dataset_id  NUMERIC(20) NOT NULL,
 study_stable_id varchar(200),
 dataset_stable_id varchar(200) NOT NULL,
 name              varchar(100),
 description              varchar(4000),
 modification_date            DATE NOT NULL,
 user_read                    NUMERIC(1) NOT NULL,
 user_write                   NUMERIC(1) NOT NULL,
 group_read                   NUMERIC(1) NOT NULL,
 group_write                  NUMERIC(1) NOT NULL,
 other_read                   NUMERIC(1) NOT NULL,
 other_write                  NUMERIC(1) NOT NULL,
 row_user_id                  NUMERIC(12) NOT NULL,
 row_group_id                 NUMERIC(3) NOT NULL,
 row_project_id               NUMERIC(4) NOT NULL,
 row_alg_invocation_id        NUMERIC(12) NOT NULL,
 FOREIGN KEY (user_dataset_id) REFERENCES apidbUserDatasets.InstalledUserDataset,
 PRIMARY KEY (dataset_id)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON ApidbUserDatasets.DatasetAttributes TO gus_w;
GRANT SELECT ON ApidbUserDatasets.DatasetAttributes TO gus_r;

CREATE SEQUENCE ApidbUserDatasets.DatasetAttributes_sq;
GRANT SELECT ON ApidbUserDatasets.DatasetAttributes_sq TO gus_w;
GRANT SELECT ON ApidbUserDatasets.DatasetAttributes_sq TO gus_r;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'DatasetAttributes',
       'Standard', 'dataset_id',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = lower('apidbuserdatasets')) d
WHERE 'datasetattributes' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

-----------------------------------------------------------
-- grant select on apidbUserDatasets.DatasetAttributes to eda with grant option;

create or replace view eda.StudyIdDatasetId as
  select study_stable_id, dataset_id
  from apidbTuning.StudyIdDatasetId
union
  select study_stable_id, dataset_stable_id
  from apidbUserDatasets.DatasetAttributes
;

grant select on eda.StudyIdDatasetId to public;

-- grant references on apidbUserDatasets.EntityTypeGraph to eda;
-- grant references on eda.EntityTypeGraph to eda;

-- grant select on apidbUserDatasets.EntityTypeGraph to eda with grant option;

create or replace view eda.UnifiedEntityTypeGraph as
  select study_stable_id, parent_stable_id, stable_id, display_name,
         display_name_plural, description, internal_abbrev,
         has_attribute_collections, is_many_to_one_with_parent
  from eda.EntityTypeGraph
union
  select study_stable_id, parent_stable_id, stable_id, display_name,
         display_name_plural, description, internal_abbrev,
         has_attribute_collections, is_many_to_one_with_parent
  from apidbUserDatasets.EntityTypeGraph
;

grant select on eda.UnifiedEntityTypeGraph to public;

-----------------------------------------------------------