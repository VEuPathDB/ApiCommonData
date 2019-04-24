CREATE TABLE apidb.CompoundPeaks (
 compound_peaks_id            NUMBER(12) NOT NULL,
 PRIMARY KEY (compound_peaks_id),
 external_database_release_id NUMBER(12), 
 FOREIGN KEY (external_database_release_id) REFERENCES SRES.EXTERNALDATABASERELEASE (external_database_release_id),
 peak_number                  NUMBER(12), 
 mass                         NUMBER(12,6),
 retention_time               NUMBER(12,6), 
 ms_polarity                  CHAR(1) CONSTRAINT ms_polarity_value CHECK (ms_polarity in ('+', '-', NULL)),
 
 modification_date            DATE NOT NULL,
 user_read                    NUMBER(1) NOT NULL,
 user_write                   NUMBER(1) NOT NULL,
 group_read                   NUMBER(1) NOT NULL,
 group_write                  NUMBER(1) NOT NULL,
 other_read                   NUMBER(1) NOT NULL,
 other_write                  NUMBER(1) NOT NULL,
 row_user_id                  NUMBER(12) NOT NULL,
 row_group_id                 NUMBER(3) NOT NULL,
 row_project_id               NUMBER(4) NOT NULL,
 row_alg_invocation_id        NUMBER(12) NOT NULL
);

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.CompoundPeaks TO gus_w;  
GRANT SELECT ON apidb.CompoundPeaks TO gus_r;  

--CREATE INDEX cp_external_database_release_id_idx ON apidb.CompoundPeaks(external_database_release_id);

-----------
CREATE SEQUENCE apidb.CompoundPeaks_sq;   

GRANT SELECT ON apidb.CompoundPeaks_sq TO gus_r;  
GRANT SELECT ON apidb.CompoundPeaks_sq TO gus_w;  
----------------------

CREATE TABLE apidb.CompoundPeaksChebi (           
 compound_peaks_chebi_id      NUMBER(12) NOT NULL,
 PRIMARY KEY (compound_peaks_chebi_id),
 compound_id                  NUMBER(15) NOT NULL, 
 FOREIGN KEY (compound_id) REFERENCES CHEBI.Compounds (id),
 compound_peaks_id            NUMBER(12) NOT NULL,
 FOREIGN KEY (compound_peaks_id) REFERENCES apidb.CompoundPeaks (compound_peaks_id),
 isotopomer                   VARCHAR2(100),

 modification_date            DATE NOT NULL,
 user_read                    NUMBER(1) NOT NULL,
 user_write                   NUMBER(1) NOT NULL,
 group_read                   NUMBER(1) NOT NULL,
 group_write                  NUMBER(1) NOT NULL,
 other_read                   NUMBER(1) NOT NULL,
 other_write                  NUMBER(1) NOT NULL,
 row_user_id                  NUMBER(12) NOT NULL,
 row_group_id                 NUMBER(3) NOT NULL,
 row_project_id               NUMBER(4) NOT NULL,
 row_alg_invocation_id        NUMBER(12) NOT NULL
);

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.CompoundPeaksChebi TO gus_w;
GRANT SELECT ON apidb.CompoundPeaksChebi TO gus_r;

-----------
CREATE SEQUENCE apidb.CompoundPeaksChebi_sq; 

GRANT SELECT ON apidb.CompoundPeaksChebi_sq TO gus_r;  
GRANT SELECT ON apidb.CompoundPeaksChebi_sq TO gus_w; 
----------------------

CREATE TABLE apidb.CompoundMassSpecResult (
 compound_mass_spec_result_id NUMBER(12) NOT NULL,
 PRIMARY KEY (compound_mass_spec_result_id), 
 protocol_app_node_id         NUMBER(10) NOT NULL,
 FOREIGN KEY (protocol_app_node_id) REFERENCES study.protocolappnode (protocol_app_node_id),
 compound_peaks_id            NUMBER(12) NOT NULL, 
 FOREIGN KEY (compound_peaks_id) REFERENCES CompoundPeaks (compound_peaks_id),
 value                        NUMBER(12), 

 modification_date            DATE NOT NULL,
 user_read                    NUMBER(1) NOT NULL,
 user_write                   NUMBER(1) NOT NULL,
 group_read                   NUMBER(1) NOT NULL,
 group_write                  NUMBER(1) NOT NULL,
 other_read                   NUMBER(1) NOT NULL,
 other_write                  NUMBER(1) NOT NULL,
 row_user_id                  NUMBER(12) NOT NULL,
 row_group_id                 NUMBER(3) NOT NULL,
 row_project_id               NUMBER(4) NOT NULL,
 row_alg_invocation_id        NUMBER(12) NOT NULL
);

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.CompoundMassSpecResult TO gus_w;
GRANT SELECT ON apidb.CompoundMassSpecResult TO gus_r; 

-----------
CREATE SEQUENCE apidb.CompoundMassSpecResult_sq;   

GRANT SELECT ON apidb.CompoundMassSpecResult_sq TO gus_r; 
GRANT SELECT ON apidb.CompoundMassSpecResult_sq TO gus_w;
----------------------

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'CompoundPeaks',
       'Standard', 'compound_peaks_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'CompoundPeaks' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);
                                        
----------------------

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'CompoundPeaksChebi',
       'Standard', 'compound_peaks_chebi_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'CompoundPeaksChebi' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);
                                    
----------------------

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'CompoundMassSpecResult',
       'Standard', 'compound_mass_spec_result_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'CompoundMassSpecResult' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);
                                                                 
----------------------

exit;
