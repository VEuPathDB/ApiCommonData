/*
CREATE USER comments
IDENTIFIED BY commentpwd
QUOTA UNLIMITED ON users 
QUOTA UNLIMITED ON gus
DEFAULT TABLESPACE gus
TEMPORARY TABLESPACE temp;

ALTER USER comments ACCOUNT LOCK;

GRANT SCHEMA_OWNER TO comments;
GRANT GUS_R TO comments;
GRANT GUS_W TO comments;
GRANT CREATE VIEW TO comments;
*/

/*
DROP TABLE comment_external_database;
DROP TABLE external_databases;
DROP TABLE locations;
DROP TABLE comments;
DROP TABLE comment_target;
DROP TABLE review_status;
*/


CREATE TABLE userlogins5.comment_target
(
  comment_target_id varchar(20) NOT NULL,
  comment_target_name varchar(200) NOT NULL,
  require_location NUMBER(1),
  CONSTRAINT comment_target_key PRIMARY KEY (comment_target_id)
);

GRANT insert, update, delete on userlogins5.comment_target to GUS_W;
GRANT select on userlogins5.comment_target to GUS_R;

CREATE TABLE userlogins5.review_status
(
  review_status_id varchar(20) NOT NULL,
  review_status_name varchar(200) NOT NULL,
  CONSTRAINT review_status PRIMARY KEY (review_status_id)
);


GRANT insert, update, delete on userlogins5.review_status to GUS_W;
GRANT select on userlogins5.review_status to GUS_R;

  
CREATE TABLE userlogins5.comments
(
  comment_id NUMBER(10) NOT NULL,
  prev_comment_id NUMBER(10),
  prev_schema VARCHAR(50),
  user_id NUMBER(12) NOT NULL,
  email varchar(255),
  comment_date date,
  comment_target_id varchar(20),
  stable_id varchar(200),
  conceptual NUMBER(1),
  project_name varchar(200),
  project_version varchar(100),
  headline varchar(2000),
  review_status_id varchar(20),
  accepted_version varchar(100),
  location_string VARCHAR(1000),
  content CLOB,
  organism VARCHAR(100),
  is_visible NUMBER(1) DEFAULT 1 NOT NULL,
  CONSTRAINT comments_pkey PRIMARY KEY (comment_id),
  CONSTRAINT comments_ct_id_fkey FOREIGN KEY (comment_target_id)
      REFERENCES userlogins5.comment_target (comment_target_id),
  CONSTRAINT comments_fk03 FOREIGN KEY (user_id)
      REFERENCES userlogins5.users (user_id),
  CONSTRAINT comments_rs_id_fkey FOREIGN KEY (review_status_id)
      REFERENCES userlogins5.review_status (review_status_id)
);

CREATE INDEX userlogins5.comments_idx01 ON userlogins5.comments (comment_target_id);
CREATE INDEX userlogins5.comments_idx02 ON userlogins5.comments (review_status_id);
CREATE UNIQUE INDEX userlogins5.comments_ux01 ON userlogins5.comments (user_id, comment_id);
CREATE UNIQUE INDEX userlogins5.comments_ux02 ON userlogins5.comments (stable_id, project_name, comment_id);

GRANT insert, update, delete on userlogins5.comments to GUS_W;
GRANT select on userlogins5.comments to GUS_R;


CREATE TABLE userlogins5.external_databases
(
  external_database_id NUMBER(10) NOT NULL,
  external_database_name varchar(200),
  external_database_version varchar(200),
  prev_schema VARCHAR(50),
  prev_external_database_id NUMBER(10),
  CONSTRAINT external_databases_pkey PRIMARY KEY (external_database_id)
);

GRANT insert, update, delete on userlogins5.external_databases to GUS_W;
GRANT select on userlogins5.external_databases to GUS_R;


CREATE TABLE userlogins5.locations
(
  comment_id NUMBER(10) NOT NULL,
  location_id NUMBER(10) NOT NULL,
  location_start NUMBER(12),
  location_end NUMBER(12),
  coordinate_type VARCHAR(20),
  is_reverse NUMBER(1),
  prev_comment_id NUMBER(10),
  prev_schema VARCHAR(50),
  CONSTRAINT locations_pkey PRIMARY KEY (comment_id, location_id),
  CONSTRAINT locations_comment_id_fkey FOREIGN KEY (comment_id)
      REFERENCES userlogins5.comments (comment_id)
);

GRANT insert, update, delete on userlogins5.locations to GUS_W;
GRANT select on userlogins5.locations to GUS_R;


CREATE TABLE userlogins5.comment_external_database
(
  external_database_id NUMBER(10) NOT NULL,
  comment_id NUMBER(10) NOT NULL,
  CONSTRAINT comment_external_database_pkey PRIMARY KEY (external_database_id, comment_id),
  CONSTRAINT comment_id_fkey FOREIGN KEY (comment_id)
      REFERENCES userlogins5.comments (comment_id),
  CONSTRAINT external_database_id_fkey FOREIGN KEY (external_database_id)
      REFERENCES userlogins5.external_databases (external_database_id)
);

CREATE INDEX userlogins5.comment_edb_idx01 ON userlogins5.comment_external_database (comment_id);

GRANT insert, update, delete on userlogins5.comment_external_database to GUS_W;
GRANT select on userlogins5.comment_external_database to GUS_R;


CREATE SEQUENCE userlogins5.comments_pkseq START WITH 1 INCREMENT BY 1;

GRANT select on userlogins5.comments_pkseq to GUS_W;
GRANT select on userlogins5.comments_pkseq to GUS_R;


CREATE SEQUENCE userlogins5.locations_pkseq START WITH 1 INCREMENT BY 1;

GRANT select on userlogins5.locations_pkseq to GUS_W;
GRANT select on userlogins5.locations_pkseq to GUS_R;


CREATE SEQUENCE userlogins5.external_databases_pkseq START WITH 1 INCREMENT BY 1;

GRANT select on userlogins5.external_databases_pkseq to GUS_W;
GRANT select on userlogins5.external_databases_pkseq to GUS_R;

exit
