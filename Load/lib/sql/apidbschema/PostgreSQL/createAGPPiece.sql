CREATE TABLE ApiDB.AGPPiece (
 agp_piece_id NUMERIC(10) not null,
 source_id varchar(80) not null,
 start_min NUMERIC(12) not null,
 end_max NUMERIC(12) not null,
 part_number NUMERIC(5) not null,
 part_type varchar(1) not null,
 piece_id varchar(80),
 piece_start  NUMERIC(12),
 piece_end  NUMERIC(12),
 is_reversed NUMERIC(1),
 gap_length  NUMERIC(12),
 gap_type varchar(20),
 has_linkage NUMERIC(1),
 linkage_evidence varchar(20),
 external_database_release_id NUMERIC(10) NOT NULL,
 MODIFICATION_DATE     TIMESTAMP,
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
 PRIMARY KEY (agp_piece_id)
);

ALTER TABLE APIDB.AGPPIECE ADD CONSTRAINT agpp_fk
      FOREIGN KEY (EXTERNAL_DATABASE_RELEASE_ID) REFERENCES sres.ExternalDatabaseRelease (EXTERNAL_DATABASE_RELEASE_ID);

CREATE INDEX AGPPIECE_REVIX6
    ON APIDB.AGPPIECE (EXTERNAL_DATABASE_RELEASE_ID, AGP_PIECE_ID)
    TABLESPACE INDX;

GRANT INSERT, SELECT, UPDATE, DELETE ON ApiDB.AGPPiece TO gus_w;
GRANT SELECT ON ApiDB.AGPPiece TO gus_r;

CREATE SEQUENCE apidb.AGPPiece_sq;

GRANT SELECT ON apidb.AGPPiece_sq TO gus_r;
GRANT SELECT ON apidb.AGPPiece_sq TO gus_w;

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'AGPPiece',
       'Standard', 'agp_piece_id',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'agppiece' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);