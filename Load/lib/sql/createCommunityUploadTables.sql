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
  execute immediate 'drop table uploads.UserFile'; 
  Exception when others then null;
End;
/


/* ***************************************************** */

CREATE TABLE uploads.UserFile
(
  UserFileId    NUMBER(20)     NOT NULL,
  FileName      VARCHAR2(255)   NOT NULL,
  Path          VARCHAR2(255),
  Checksum      VARCHAR2(64)    NOT NULL,
  Filesize      NUMBER(20),     NOT NULL,
  Format        VARCHAR2(255),
  UploadTime    TIMESTAMP      NOT NULL,
  OwnerUserId   VARCHAR2(40)   NOT NULL, /* userlogins3.users.signature */
  Email         VARCHAR2(255),
  Title         VARCHAR2(4000),
  Notes         VARCHAR2(4000),
  ProjectName   VARCHAR2(200),
  ProjectVersion VARCHAR2(100),
  CONSTRAINT fieldid_pkey   PRIMARY KEY (UserFileId)
);

GRANT insert, update, delete on uploads.UserFile to GUS_W;
GRANT select on uploads.UserFile to GUS_R;

CREATE SEQUENCE uploads.UserFile_pkseq START WITH 1 INCREMENT BY 1;
GRANT select on uploads.UserFile_pkseq to GUS_W;
GRANT select on uploads.UserFile_pkseq to GUS_R;


