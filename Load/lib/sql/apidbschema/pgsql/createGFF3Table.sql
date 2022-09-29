------------------------------------------------------------------------------

CREATE TABLE ApiDB.GFF3 (
 gff3_feature_id       NUMERIC(10),
 na_sequence_id        NUMERIC(10) not null,
 source                VARCHAR(50),
 sequence_ontology_id  NUMERIC(10) not null,
 mapping_start                 NUMERIC(8),
 mapping_end                   NUMERIC(8),
 score                 FLOAT,
 is_reversed           NUMERIC(3),
 phase                 VARCHAR(1),
 attr                  TEXT,
 parent_attr           VARCHAR(100),
 id_attr               VARCHAR(100),
 external_database_release_id NUMERIC(10),
 MODIFICATION_DATE     DATE,
 USER_READ             NUMERIC(1),
 USER_WRITE            NUMERIC(1),
 GROUP_READ            NUMERIC(1),
 GROUP_WRITE           NUMERIC(1),
 OTHER_READ            NUMERIC(1),
 OTHER_WRITE           NUMERIC(1),
 ROW_USER_ID           NUMERIC(12),
 ROW_GROUP_ID          NUMERIC(3),
 ROW_PROJECT_ID        NUMERIC(4),
 ROW_ALG_INVOCATION_ID NUMERIC(12),
 FOREIGN KEY (na_sequence_id) REFERENCES DoTS.NaSequenceImp (na_sequence_id),
 FOREIGN KEY (sequence_ontology_id) REFERENCES Sres.OntologyTerm (ontology_term_id),
 FOREIGN KEY (external_database_release_id) REFERENCES SRes.ExternalDatabaseRelease (external_database_release_id),
 PRIMARY KEY (gff3_feature_id)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON ApiDB.GFF3 TO gus_w;
GRANT SELECT ON ApiDB.GFF3 TO gus_r;

CREATE INDEX gff3_loc_idx
ON ApiDB.GFF3 (na_sequence_id, mapping_start, mapping_end) tablespace indx;

CREATE INDEX gff3_revfk1_idx
ON ApiDB.GFF3 (sequence_ontology_id, gff3_feature_id) tablespace indx;

CREATE INDEX gff3_revfk2_idx
ON ApiDB.GFF3 (external_database_release_id, gff3_feature_id) tablespace indx;

CREATE SEQUENCE apidb.GFF3_sq;

GRANT SELECT ON apidb.GFF3_sq TO gus_r;
GRANT SELECT ON apidb.GFF3_sq TO gus_w;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'GFF3',
       'Standard', 'gff3_feature_id',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'gff3' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

CREATE TABLE ApiDB.GFF3AttributeKey (
 gff3_attribute_key_id NUMERIC(38) not null,
 name	               VARCHAR(64) not null,
 MODIFICATION_DATE     DATE,
 USER_READ             NUMERIC(1),
 USER_WRITE            NUMERIC(1),
 GROUP_READ            NUMERIC(1),
 GROUP_WRITE           NUMERIC(1),
 OTHER_READ            NUMERIC(1),
 OTHER_WRITE           NUMERIC(1),
 ROW_USER_ID           NUMERIC(12),
 ROW_GROUP_ID          NUMERIC(3),
 ROW_PROJECT_ID        NUMERIC(4),
 ROW_ALG_INVOCATION_ID NUMERIC(12),
 PRIMARY KEY (gff3_attribute_key_id)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON ApiDB.GFF3AttributeKey TO gus_w;
GRANT SELECT ON ApiDB.GFF3AttributeKey TO gus_r;

CREATE SEQUENCE apidb.GFF3AttributeKey_sq;

GRANT SELECT ON apidb.GFF3AttributeKey_sq TO gus_r;
GRANT SELECT ON apidb.GFF3AttributeKey_sq TO gus_w;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'GFF3AttributeKey',
       'Standard', 'gff3_attribute_key_id',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'gff3attributekey' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

CREATE TABLE ApiDB.GFF3Attributes (
 gff3_attribute_id     NUMERIC(38) not null,
 gff3_attribute_key_id NUMERIC(38) not null,
 gff3_feature_id       NUMERIC(10) not null,
 value	               VARCHAR(300) not null,
 MODIFICATION_DATE     DATE,
 USER_READ             NUMERIC(1),
 USER_WRITE            NUMERIC(1),
 GROUP_READ            NUMERIC(1),
 GROUP_WRITE           NUMERIC(1),
 OTHER_READ            NUMERIC(1),
 OTHER_WRITE           NUMERIC(1),
 ROW_USER_ID           NUMERIC(12),
 ROW_GROUP_ID          NUMERIC(3),
 ROW_PROJECT_ID        NUMERIC(4),
 ROW_ALG_INVOCATION_ID NUMERIC(12),
 FOREIGN KEY (gff3_attribute_key_id) REFERENCES Apidb.GFF3AttributeKey (gff3_attribute_key_id),
 FOREIGN KEY (gff3_feature_id) REFERENCES ApiDB.GFF3 (gff3_feature_id), 
 PRIMARY KEY (gff3_attribute_id)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON ApiDB.GFF3Attributes TO gus_w;
GRANT SELECT ON ApiDB.GFF3Attributes TO gus_r;

CREATE SEQUENCE apidb.GFF3Attributes_sq;

CREATE INDEX gff3att_revfk1_idx
ON ApiDB.GFF3Attributes (gff3_feature_id, gff3_attribute_id) tablespace indx;

CREATE INDEX gff3att_revfk2_idx
ON ApiDB.GFF3Attributes (gff3_attribute_key_id, gff3_attribute_id) tablespace indx;

GRANT SELECT ON apidb.GFF3Attributes_sq TO gus_r;
GRANT SELECT ON apidb.GFF3Attributes_sq TO gus_w;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'GFF3Attributes',
       'Standard', 'gff3_attribute_id',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'gff3attributes' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);
