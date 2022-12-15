CREATE TABLE ApiDB.CompoundPeaks (
   COMPOUND_PEAKS_ID            NUMERIC(12)      NOT NULL,
   EXTERNAL_DATABASE_RELEASE_ID NUMERIC(12),
   PEAK_ID                      NUMERIC(12),
   MASS                         NUMERIC(12,6),
   RETENTION_TIME               NUMERIC(12,6),
   MS_POLARITY                  CHAR(1),
   MODIFICATION_DATE            TIMESTAMP        NOT NULL,
   USER_READ                    NUMERIC(1)       NOT NULL,
   USER_WRITE                   NUMERIC(1)       NOT NULL,
   GROUP_READ                   NUMERIC(1)       NOT NULL,
   GROUP_WRITE                  NUMERIC(1)       NOT NULL,
   OTHER_READ                   NUMERIC(1)       NOT NULL,
   OTHER_WRITE                  NUMERIC(1)       NOT NULL,
   ROW_USER_ID                  NUMERIC(12)      NOT NULL,
   ROW_GROUP_ID                 NUMERIC(3)       NOT NULL,
   ROW_PROJECT_ID               NUMERIC(4)       NOT NULL,
   ROW_ALG_INVOCATION_ID        NUMERIC(12)      NOT NULL,
   PRIMARY KEY (COMPOUND_PEAKS_ID),
   FOREIGN KEY (EXTERNAL_DATABASE_RELEASE_ID) REFERENCES SRes.ExternalDatabaseRelease (EXTERNAL_DATABASE_RELEASE_ID) 
);

GRANT INSERT, SELECT, UPDATE, DELETE ON ApiDB.CompoundPeaks TO gus_w;  
GRANT SELECT ON ApiDB.CompoundPeaks TO gus_r;  

CREATE INDEX cp_extDbRlsIx ON apidb.CompoundPeaks(external_database_release_id, compound_peaks_id) TABLESPACE indx;

-----------
CREATE SEQUENCE ApiDB.CompoundPeaks_SQ;    

GRANT SELECT ON ApiDB.CompoundPeaks_SQ TO gus_r;
GRANT SELECT ON ApiDB.CompoundPeaks_SQ TO gus_w;
----------------------

CREATE TABLE ApiDB.CompoundPeaksChebi (
   COMPOUND_PEAKS_CHEBI_ID      NUMERIC(12)      NOT NULL,
   COMPOUND_ID                  NUMERIC(15),
   COMPOUND_PEAKS_ID            NUMERIC(12)      NOT NULL,
   ISOTOPOMER                   VARCHAR(100),
   USER_COMPOUND_NAME           VARCHAR(200),
   IS_PREFERRED_COMPOUND        NUMERIC(1),
   MODIFICATION_DATE            DATE            NOT NULL,
   USER_READ                    NUMERIC(1)       NOT NULL,
   USER_WRITE                   NUMERIC(1)       NOT NULL,
   GROUP_READ                   NUMERIC(1)       NOT NULL,
   GROUP_WRITE                  NUMERIC(1)       NOT NULL,
   OTHER_READ                   NUMERIC(1)       NOT NULL,
   OTHER_WRITE                  NUMERIC(1)       NOT NULL,
   ROW_USER_ID                  NUMERIC(12)      NOT NULL,
   ROW_GROUP_ID                 NUMERIC(3)       NOT NULL,
   ROW_PROJECT_ID               NUMERIC(4)       NOT NULL,
   ROW_ALG_INVOCATION_ID        NUMERIC(12)      NOT NULL,
   PRIMARY KEY (COMPOUND_PEAKS_CHEBI_ID),
   FOREIGN KEY (COMPOUND_PEAKS_ID) REFERENCES ApiDB.CompoundPeaks (COMPOUND_PEAKS_ID)
);

CREATE INDEX cpc_cmppIx ON apidb.CompoundPeaksChebi(compound_peaks_id, compound_peaks_chebi_id) TABLESPACE indx;
CREATE INDEX cpc_cmpIx ON apidb.CompoundPeaksChebi(compound_id, compound_peaks_chebi_id) TABLESPACE indx;

GRANT INSERT, SELECT, UPDATE, DELETE ON ApiDB.CompoundPeaksChebi TO gus_w;  
GRANT SELECT ON ApiDB.CompoundPeaksChebi TO gus_r;  

-----------
CREATE SEQUENCE ApiDB.CompoundPeaksChebi_SQ;    

GRANT SELECT ON ApiDB.CompoundPeaksChebi_SQ TO gus_r;
GRANT SELECT ON ApiDB.CompoundPeaksChebi_SQ TO gus_w;
----------------------

CREATE TABLE ApiDB.CompoundMassSpecResult (
   COMPOUND_MASS_SPEC_RESULT_ID NUMERIC(12)      NOT NULL,
   PROTOCOL_APP_NODE_ID         NUMERIC(10)      NOT NULL,
   COMPOUND_PEAKS_ID            NUMERIC(12)      NOT NULL,
   PERCENTILE                   NUMERIC(16,13),
   STANDARD_ERROR               NUMERIC(14,2),
   VALUE                        NUMERIC(12),
   MODIFICATION_DATE            DATE            NOT NULL,
   USER_READ                    NUMERIC(1)       NOT NULL,
   USER_WRITE                   NUMERIC(1)       NOT NULL,
   GROUP_READ                   NUMERIC(1)       NOT NULL,
   GROUP_WRITE                  NUMERIC(1)       NOT NULL,
   OTHER_READ                   NUMERIC(1)       NOT NULL,
   OTHER_WRITE                  NUMERIC(1)       NOT NULL,
   ROW_USER_ID                  NUMERIC(12)      NOT NULL,
   ROW_GROUP_ID                 NUMERIC(3)       NOT NULL,
   ROW_PROJECT_ID               NUMERIC(4)       NOT NULL,
   ROW_ALG_INVOCATION_ID        NUMERIC(12)      NOT NULL,
   PRIMARY KEY (COMPOUND_MASS_SPEC_RESULT_ID),
   FOREIGN KEY (PROTOCOL_APP_NODE_ID) REFERENCES Study.ProtocolAppNode (PROTOCOL_APP_NODE_ID),
   FOREIGN KEY (COMPOUND_PEAKS_ID) REFERENCES ApiDB.CompoundPeaks (COMPOUND_PEAKS_ID)
);

GRANT INSERT, SELECT, UPDATE, DELETE ON ApiDB.CompoundMassSpecResult TO gus_w;  
GRANT SELECT ON ApiDB.CompoundMassSpecResult TO gus_r;  

CREATE INDEX cmsr_panIx ON apidb.CompoundMassSpecResult(protocol_app_node_id, compound_mass_spec_result_id) TABLESPACE indx;
CREATE INDEX cmsr_cpiIx ON apidb.CompoundMassSpecResult(compound_peaks_id, compound_mass_spec_result_id) TABLESPACE indx;

-----------
CREATE SEQUENCE ApiDB.CompoundMassSpecResult_SQ;  

GRANT SELECT ON ApiDB.CompoundMassSpecResult_SQ TO gus_r; 
GRANT SELECT ON ApiDB.CompoundMassSpecResult_SQ TO gus_w; 
----------------------

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable,
     modification_date, user_read, user_write, group_read, group_write,
     other_read, other_write, row_user_id, row_group_id, row_project_id,
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'CompoundPeaks',
       'Standard', 'COMPOUND_PEAKS_ID',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'CompoundPeaks' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

----------------------

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable,
     modification_date, user_read, user_write, group_read, group_write,
     other_read, other_write, row_user_id, row_group_id, row_project_id,
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'CompoundPeaksChebi',
       'Standard', 'COMPOUND_PEAKS_CHEBI_ID',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'CompoundPeaksChebi' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

----------------------

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable,
     modification_date, user_read, user_write, group_read, group_write,
     other_read, other_write, row_user_id, row_group_id, row_project_id,
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'CompoundMassSpecResult',
       'Standard', 'COMPOUND_MASS_SPEC_RESULT_ID',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'CompoundMassSpecResult' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);
