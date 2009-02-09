/*
    Table Definitions for Community File Uploads
*/

/*

CREATE USER uploads
IDENTIFIED BY uploadthis
QUOTA UNLIMITED ON users 
QUOTA UNLIMITED ON gus
DEFAULT TABLESPACE gus
TEMPORARY TABLESPACE temp;

ALTER USER uploads ACCOUNT LOCK;

GRANT SCHEMA_OWNER TO uploads;
GRANT GUS_R TO uploads;
GRANT GUS_W TO uploads;
GRANT CREATE VIEW TO uploads;

*/

/* ***************************************************** */

Begin  
  execute immediate 'drop sequence uploads.UserFile_pkseq'; 
  Exception when others then null;
End;
/
Begin  
  execute immediate 'drop sequence uploads.Tag_pkseq'; 
  Exception when others then null;
End;
/
Begin  
  execute immediate 'drop table uploads.UserFileTag'; 
  Exception when others then null;
End;
/
Begin  
  execute immediate 'drop table uploads.UserFileFeature'; 
  Exception when others then null;
End;
/
Begin  
  execute immediate 'drop table uploads.BLAH';
  Exception when others then null;
End;
/
Begin  
  execute immediate 'drop table uploads.UserFile'; 
  Exception when others then null;
End;
/
Begin  
  execute immediate 'drop table uploads.Tag'; 
  Exception when others then null;
End;
/


/* ***************************************************** */

CREATE TABLE uploads.UserFile
(
  UserFileId    NUMBER(20)     NOT NULL,
  FileName      VARCHAR(255)   NOT NULL,
  Checksum      VARCHAR(64)    NOT NULL,
  UploadTime    TIMESTAMP      NOT NULL,
  OwnerUserId   VARCHAR2(40)   NOT NULL, /* userlogins3.users.signature */
  Title         VARCHAR(4000),
  Notes         VARCHAR(4000),
  CONSTRAINT fieldid_pkey   PRIMARY KEY (UserFileId)
);

GRANT insert, update, delete on uploads.UserFile to GUS_W;
GRANT select on uploads.UserFile to GUS_R;

CREATE SEQUENCE uploads.UserFile_pkseq START WITH 1 INCREMENT BY 1;
GRANT select on uploads.UserFile_pkseq to GUS_W;
GRANT select on uploads.UserFile_pkseq to GUS_R;



CREATE TABLE uploads.Tag
(
  TagId       NUMBER(20)     NOT NULL,
  TagName     VARCHAR(255)   NOT NULL,
  /* is_internal == 1 signifies a special tag for specific grouping */
  Is_Internal NUMBER(1) check (Is_Internal in (0,1)),
  CONSTRAINT  tagid_pkey     PRIMARY KEY (TagId)
);

GRANT insert, update, delete on uploads.Tag to GUS_W;
GRANT select on uploads.Tag to GUS_R;

CREATE SEQUENCE uploads.Tag_pkseq START WITH 1 INCREMENT BY 1;
GRANT select on uploads.Tag_pkseq to GUS_W;
GRANT select on uploads.Tag_pkseq to GUS_R;


CREATE TABLE uploads.UserFileTag
(
  UserFileId  NUMBER(20)     NOT NULL,
  TagId       NUMBER(20)     NOT NULL,
  CONSTRAINT uploads_file_fid_fkey FOREIGN KEY (UserFileId)
      REFERENCES uploads.UserFile (UserFileId),
  CONSTRAINT uploads_tag_tid_fkey FOREIGN KEY (TagId)
      REFERENCES uploads.Tag (TagId)
);

GRANT insert, update, delete on uploads.UserFileTag to GUS_W;
GRANT select on uploads.UserFileTag to GUS_R;



CREATE TABLE uploads.UserFileFeature
(
  UserFileId        NUMBER(20)     NOT NULL,
  FeatureStableId   VARCHAR(256)   NOT NULL,
  FeatureTable      VARCHAR(256)   NOT NULL,
  CONSTRAINT uploads_uff_fid_fkey FOREIGN KEY (UserFileId)
      REFERENCES uploads.UserFile (UserFileId)
);

GRANT insert, update, delete on uploads.UserFileFeature to GUS_W;
GRANT select on uploads.UserFileFeature to GUS_R;

