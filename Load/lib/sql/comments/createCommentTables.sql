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

/*
DROP TABLE comment_external_database;
DROP TABLE external_databases;
DROP TABLE locations;
DROP TABLE comments;
DROP TABLE comment_target;
DROP TABLE review_status;
*/


CREATE TABLE comments.comment_target
(
  comment_target_id varchar(20) NOT NULL,
  comment_target_name varchar(200) NOT NULL,
  allow_location NUMBER(1),
  allow_reverse NUMBER(1),
  location_description varchar(4000),
  CONSTRAINT comment_target_key PRIMARY KEY (comment_target_id)
);

GRANT insert, update, delete on comments.comment_target to GUS_W;
GRANT select on comments.comment_target to GUS_R;

CREATE TABLE comments.review_status
(
  review_status_id varchar(20) NOT NULL,
  review_status_name varchar(200) NOT NULL,
  CONSTRAINT review_status PRIMARY KEY (review_status_id)
);


GRANT insert, update, delete on comments.review_status to GUS_W;
GRANT select on comments.review_status to GUS_R;

  
CREATE TABLE comments.comments
(
  comment_id NUMBER(10) NOT NULL,
  email varchar(255),
  comment_date date,
  comment_target_id varchar(20),
  stable_id varchar(200),
  conceptual NUMBER(1),
  project_name varchar(200),
  project_version varchar(100),
  headline varchar(2000),
  content varchar(4000),
  review_status_id varchar(20),
  accepted_version varchar(100),
  CONSTRAINT comments_pkey PRIMARY KEY (comment_id),
  CONSTRAINT comments_ct_id_fkey FOREIGN KEY (comment_target_id)
      REFERENCES comments.comment_target (comment_target_id),
  CONSTRAINT comments_rs_id_fkey FOREIGN KEY (review_status_id)
      REFERENCES comments.review_status (review_status_id)
);

GRANT insert, update, delete on comments.comments to GUS_W;
GRANT select on comments.comments to GUS_R;


CREATE TABLE comments.external_databases
(
  external_database_id NUMBER(10) NOT NULL,
  external_database_name varchar(200),
  external_database_version varchar(200),
  CONSTRAINT external_databases_pkey PRIMARY KEY (external_database_id)
);

GRANT insert, update, delete on comments.external_databases to GUS_W;
GRANT select on comments.external_databases to GUS_R;


CREATE TABLE comments.locations
(
  comment_id NUMBER(10) NOT NULL,
  location_id NUMBER(10) NOT NULL,
  location_start NUMBER(12),
  location_end NUMBER(12),
  is_reverse NUMBER(1),
  CONSTRAINT locations_pkey PRIMARY KEY (comment_id, location_id),
  CONSTRAINT locations_comment_id_fkey FOREIGN KEY (comment_id)
      REFERENCES comments.comments (comment_id)
);

GRANT insert, update, delete on comments.locations to GUS_W;
GRANT select on comments.locations to GUS_R;


CREATE TABLE comments.comment_external_database
(
  external_database_id NUMBER(10) NOT NULL,
  comment_id NUMBER(10) NOT NULL,
  CONSTRAINT comment_external_database_pkey PRIMARY KEY (external_database_id, comment_id),
  CONSTRAINT comment_id_fkey FOREIGN KEY (comment_id)
      REFERENCES comments.comments (comment_id),
  CONSTRAINT external_database_id_fkey FOREIGN KEY (external_database_id)
      REFERENCES comments.external_databases (external_database_id)
);

GRANT insert, update, delete on comments.comment_external_database to GUS_W;
GRANT select on comments.comment_external_database to GUS_R;


CREATE SEQUENCE comments.comments_pkseq START WITH 1 INCREMENT BY 1;

GRANT select on comments.comments_pkseq to GUS_W;
GRANT select on comments.comments_pkseq to GUS_R;


CREATE SEQUENCE comments.locations_pkseq START WITH 1 INCREMENT BY 1;

GRANT select on comments.locations_pkseq to GUS_W;
GRANT select on comments.locations_pkseq to GUS_R;


CREATE SEQUENCE comments.external_databases_pkseq START WITH 1 INCREMENT BY 1;

GRANT select on comments.external_databases_pkseq to GUS_W;
GRANT select on comments.external_databases_pkseq to GUS_R;

exit
