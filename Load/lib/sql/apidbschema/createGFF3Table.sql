GRANT references ON DoTS.NaSequenceImp TO ApiDB;
GRANT references ON SRes.ExternalDatabaseRelease TO ApiDB;

------------------------------------------------------------------------------

CREATE TABLE ApiDB.GFF3 (
 gff3_feature_id       NUMBER(10),  
 na_sequence_id        NUMBER(10),  
 seqid                 VARCHAR2(20),  
 source                VARCHAR2(20),  
 type                  VARCHAR2(20),  
 start                 NUMBER(8),
 end                   NUMBER(8),
 score                 FLOAT,
 is_reversed           NUMBER(3),
 phase                 NUMBER(3),
 attributes            VARCHAR2(500),  
 external_database_release_id NUMBER(10),
 MODIFICATION_DATE     DATE,
 USER_READ             NUMBER(1),
 USER_WRITE            NUMBER(1),
 GROUP_READ            NUMBER(1),
 GROUP_WRITE           NUMBER(1),
 OTHER_READ            NUMBER(1),
 OTHER_WRITE           NUMBER(1),
 ROW_USER_ID           NUMBER(12),
 ROW_GROUP_ID          NUMBER(3),
 ROW_PROJECT_ID        NUMBER(4),
 ROW_ALG_INVOCATION_ID NUMBER(12),
 FOREIGN KEY (na_sequence_id) REFERENCES DoTS.NaSequenceImp (na_sequence_id),
 FOREIGN KEY (external_database_release_id) REFERENCES SRes.ExternalDatabaseRelease (external_database_release_id),
 PRIMARY KEY (gff3_feature_id)
);

CREATE INDEX apidb.gff3_feature_id_idx
ON apidb.GFF3 (gff3_feature_id);
