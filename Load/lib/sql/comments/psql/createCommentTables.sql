/*
DROP SEQUENCE userlogins5.commentStableId_pkseq; 
DROP SEQUENCE userlogins5.commentTargetCategory_pkseq; 
DROP SEQUENCE userlogins5.commentReference_pkseq; 
DROP SEQUENCE userlogins5.commentFile_pkseq; 
DROP SEQUENCE userlogins5.commentSequence_pkseq; 
DROP SEQUENCE userlogins5.comments_pkseq; 
DROP SEQUENCE userlogins5.locations_pkseq; 
DROP SEQUENCE userlogins5.external_databases_pkseq; 

DROP TABLE userlogins5.CommentStableId;
DROP TABLE userlogins5.CommentFile;
DROP TABLE userlogins5.CommentTargetCategory;
DROP TABLE userlogins5.TargetCategory;
DROP TABLE userlogins5.CommentReference;
DROP TABLE userlogins5.CommentSequence;

DROP TABLE userlogins5.comment_external_database;
DROP TABLE userlogins5.external_databases;
DROP TABLE userlogins5.locations;
DROP TABLE userlogins5.comments;
DROP TABLE userlogins5.comment_target;
DROP TABLE userlogins5.review_status;
*/

CREATE SEQUENCE userlogins5.comments_pkseq START WITH 100000000 INCREMENT BY 10;

GRANT select on userlogins5.comments_pkseq to GUS_W;
GRANT select on userlogins5.comments_pkseq to GUS_R;


CREATE SEQUENCE userlogins5.locations_pkseq START WITH 100000000 INCREMENT BY 10;

GRANT select on userlogins5.locations_pkseq to GUS_W;
GRANT select on userlogins5.locations_pkseq to GUS_R;


CREATE SEQUENCE userlogins5.external_databases_pkseq START WITH 100000000 INCREMENT BY 10;

GRANT select on userlogins5.external_databases_pkseq to GUS_W;
GRANT select on userlogins5.external_databases_pkseq to GUS_R;


CREATE SEQUENCE userlogins5.commentTargetCategory_pkseq START WITH 100000000 INCREMENT BY 10;

GRANT select on userlogins5.commentTargetCategory_pkseq to GUS_W;
GRANT select on userlogins5.commentTargetCategory_pkseq to GUS_R;


CREATE SEQUENCE userlogins5.commentReference_pkseq START WITH 100000000 INCREMENT BY 10;
GRANT select on userlogins5.commentReference_pkseq to GUS_W;
GRANT select on userlogins5.commentReference_pkseq to GUS_R;


CREATE SEQUENCE userlogins5.commentSequence_pkseq START WITH 100000000 INCREMENT BY 10;
GRANT select on userlogins5.commentSequence_pkseq to GUS_W;
GRANT select on userlogins5.commentSequence_pkseq to GUS_R;


CREATE SEQUENCE userlogins5.commentFile_pkseq START WITH 100000000 INCREMENT BY 10;
GRANT select on userlogins5.commentFile_pkseq to GUS_W;
GRANT select on userlogins5.commentFile_pkseq to GUS_R;

CREATE SEQUENCE userlogins5.commentStableId_pkseq START WITH 100000000 INCREMENT BY 10;
GRANT select on userlogins5.commentStableId_pkseq to GUS_W;
GRANT select on userlogins5.commentStableId_pkseq to GUS_R;



CREATE TABLE userlogins5.comment_target
(
  comment_target_id varchar(20) NOT NULL,
  comment_target_name varchar(200) NOT NULL,
  require_location NUMERIC(1),
  CONSTRAINT comment_target_key PRIMARY KEY (comment_target_id)
);

GRANT insert, update, delete on userlogins5.comment_target to GUS_W;
GRANT select on userlogins5.comment_target to GUS_R;

CREATE TABLE userlogins5.review_status
(
  review_status_id varchar(20) NOT NULL,
  review_status_name varchar(200) NOT NULL,
  CONSTRAINT review_status_key PRIMARY KEY (review_status_id)
);

GRANT insert, update, delete on userlogins5.review_status to GUS_W;
GRANT select on userlogins5.review_status to GUS_R;

  
CREATE TABLE userlogins5.comments
(
  comment_id NUMERIC(10) NOT NULL,
  prev_comment_id NUMERIC(10),
  prev_schema VARCHAR(50),
  user_id NUMERIC(12) NOT NULL,
  email varchar(255),
  comment_date timestamp,
  comment_target_id varchar(20),
  stable_id varchar(200),
  conceptual NUMERIC(1),
  project_name varchar(200),
  project_version varchar(100),
  headline varchar(2000),
  review_status_id varchar(20),
  accepted_version varchar(100),
  location_string VARCHAR(1000),
  content text,
  organism VARCHAR(100),
  is_visible NUMERIC(1) DEFAULT 1 NOT NULL,
  CONSTRAINT comments_pkey PRIMARY KEY (comment_id),
  CONSTRAINT comments_ct_id_fkey FOREIGN KEY (comment_target_id)
      REFERENCES userlogins5.comment_target (comment_target_id),
  CONSTRAINT comments_fk03 FOREIGN KEY (user_id)
      REFERENCES userlogins5.users (user_id),
  CONSTRAINT comments_rs_id_fkey FOREIGN KEY (review_status_id)
      REFERENCES userlogins5.review_status (review_status_id)
);

CREATE INDEX comments_idx02 ON userlogins5.comments (review_status_id, project_name, comment_id);
CREATE INDEX comments_idx03
    ON userlogins5.comments (project_name, is_visible, stable_id, comment_id, comment_target_id, review_status_id);
CREATE UNIQUE INDEX comments_ux01 ON userlogins5.comments (user_id, comment_id);
CREATE UNIQUE INDEX comments_ux02 ON userlogins5.comments (stable_id, project_name, comment_id);

GRANT insert, update, delete on userlogins5.comments to GUS_W;
GRANT select on userlogins5.comments to GUS_R;


CREATE TABLE userlogins5.external_databases
(
  external_database_id NUMERIC(10) NOT NULL,
  external_database_name varchar(200),
  external_database_version varchar(200),
  prev_schema VARCHAR(50),
  prev_external_database_id NUMERIC(10),
  CONSTRAINT external_databases_pkey PRIMARY KEY (external_database_id)
);

GRANT insert, update, delete on userlogins5.external_databases to GUS_W;
GRANT select on userlogins5.external_databases to GUS_R;


CREATE TABLE userlogins5.locations
(
  comment_id NUMERIC(10) NOT NULL,
  location_id NUMERIC(10) NOT NULL,
  location_start NUMERIC(12),
  location_end NUMERIC(12),
  coordinate_type VARCHAR(20),
  is_reverse NUMERIC(1),
  prev_comment_id NUMERIC(10),
  prev_schema VARCHAR(50),
  CONSTRAINT locations_pkey PRIMARY KEY (comment_id, location_id),
  CONSTRAINT locations_comment_id_fkey FOREIGN KEY (comment_id)
      REFERENCES userlogins5.comments (comment_id)
);

GRANT insert, update, delete on userlogins5.locations to GUS_W;
GRANT select on userlogins5.locations to GUS_R;


CREATE TABLE userlogins5.comment_external_database
(
  external_database_id NUMERIC(10) NOT NULL,
  comment_id NUMERIC(10) NOT NULL,
  CONSTRAINT comment_external_database_pkey PRIMARY KEY (external_database_id, comment_id),
  CONSTRAINT comment_id_fkey FOREIGN KEY (comment_id)
      REFERENCES userlogins5.comments (comment_id),
  CONSTRAINT external_database_id_fkey FOREIGN KEY (external_database_id)
      REFERENCES userlogins5.external_databases (external_database_id)
);

CREATE INDEX comment_edb_idx01 ON userlogins5.comment_external_database (comment_id);

GRANT insert, update, delete on userlogins5.comment_external_database to GUS_W;
GRANT select on userlogins5.comment_external_database to GUS_R;

-- view of comments with stable_id either as-is or mapped through commentStableId
create or replace view userlogins5.mappedComment as
select c.comment_id, c.user_id, c.email, c.comment_date, c.comment_target_id,
       idMap.stable_id, c.conceptual, c.project_name, c.project_version, c.headline,
       c.review_status_id, c.accepted_version, c.location_string, c.organism, c.is_visible
from userlogins5.comments c, 
     (select stable_id, comment_id
         from userlogins5.comments
       union
         select stable_id, comment_id
         from userlogins5.commentStableId) idMap
where c.comment_id = idMap.comment_id;

grant select on userlogins5.mappedComment to gus_r;
