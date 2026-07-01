reset role;

CREATE SCHEMA IF NOT EXISTS usercomments AUTHORIZATION userdb_owner;
GRANT USAGE ON SCHEMA usercomments TO usercomments_r;

-- set role COMM_WDK_W;

---------------------------------------------------------------------------------
-- These tables contain static enumerations referenced by other tables
-- They are meant to be updated manually.
---------------------------------------------------------------------------------

CREATE TABLE usercomments.comment_target (
  comment_target_id   VARCHAR(20)  NOT NULL,
  comment_target_name VARCHAR(200) NOT NULL,
  require_location    BOOLEAN,
  CONSTRAINT comment_target_key PRIMARY KEY (comment_target_id)
);

ALTER TABLE usercomments.comment_target OWNER TO userdb_owner;
GRANT SELECT ON usercomments.comment_target TO usercomments_r;

-------------------------------------------------------------------------

CREATE TABLE usercomments.targetcategory (
  target_category_id BIGINT       NOT NULL,
  category           VARCHAR(100) NOT NULL,
  comment_target_id  VARCHAR(20)  NOT NULL,
  CONSTRAINT target_category_key PRIMARY KEY (target_category_id)
);

ALTER TABLE usercomments.targetcategory OWNER TO userdb_owner;

GRANT SELECT ON usercomments.targetcategory TO usercomments_r;

-------------------------------------------------------------------------

CREATE TABLE usercomments.review_status (
  review_status_id   VARCHAR(20)  NOT NULL,
  review_status_name VARCHAR(200) NOT NULL,
  CONSTRAINT review_status_key PRIMARY KEY (review_status_id)
);

ALTER TABLE usercomments.review_status OWNER TO userdb_owner;
GRANT SELECT ON usercomments.review_status TO usercomments_r;

---------------------------------------------------------------------------------
-- Comment Data Tables
---------------------------------------------------------------------------------

CREATE TABLE usercomments.comments (
  comment_id        BIGINT               NOT NULL,
  prev_comment_id   BIGINT,
  prev_schema       VARCHAR(50),
  user_id           BIGINT               NOT NULL,
  email             VARCHAR(255),
  comment_date      TIMESTAMP,
  comment_target_id VARCHAR(20),
  stable_id         VARCHAR(200),
  conceptual        NUMERIC(1),
  project_name      VARCHAR(200),
  project_version   VARCHAR(100),
  headline          VARCHAR(2000),
  review_status_id  VARCHAR(20),
  accepted_version  VARCHAR(100),
  location_string   VARCHAR(1000),
  content           TEXT,
  organism          VARCHAR(100),
  is_visible        BOOLEAN DEFAULT TRUE NOT NULL,
  CONSTRAINT comments_pkey PRIMARY KEY (comment_id),
  CONSTRAINT comments_uid_fkey FOREIGN KEY (user_id) REFERENCES wdkuser.users(user_id),
  CONSTRAINT comments_ct_id_fkey FOREIGN KEY (comment_target_id) REFERENCES usercomments.comment_target(comment_target_id),
  CONSTRAINT comments_rs_id_fkey FOREIGN KEY (review_status_id) REFERENCES usercomments.review_status(review_status_id)
);

CREATE INDEX comments_idx02 ON usercomments.comments(review_status_id, project_name, comment_id);
CREATE INDEX comments_idx03 ON usercomments.comments(project_name, is_visible, stable_id, comment_id, comment_target_id,
                                                     review_status_id);
CREATE UNIQUE INDEX comments_ux01 ON usercomments.comments(user_id, comment_id);
CREATE UNIQUE INDEX comments_ux02 ON usercomments.comments(stable_id, project_name, comment_id);

ALTER TABLE usercomments.comments OWNER TO userdb_owner;
GRANT SELECT ON usercomments.comments TO usercomments_r;
GRANT INSERT, UPDATE, DELETE ON usercomments.comments TO usercomments_w;

CREATE SEQUENCE usercomments.comments_pkseq START WITH 100000000 INCREMENT BY 10;
ALTER SEQUENCE usercomments.comments_pkseq OWNER TO userdb_owner;
GRANT USAGE, SELECT ON usercomments.comments_pkseq TO usercomments_r;

-------------------------------------------------------------------------

CREATE TABLE usercomments.commentfile (
  file_id    BIGINT        NOT NULL,
  name       VARCHAR(500)  NOT NULL,
  notes      VARCHAR(4000) NOT NULL,
  comment_id BIGINT        NOT NULL,
  CONSTRAINT file_id_key PRIMARY KEY (file_id),
  CONSTRAINT comment_id_file_fkey FOREIGN KEY (comment_id)
    REFERENCES usercomments.comments(comment_id)
);

CREATE INDEX commentfile_idx01 ON usercomments.commentfile(comment_id, file_id);

ALTER TABLE usercomments.commentfile OWNER TO userdb_owner;
GRANT SELECT ON usercomments.commentfile TO usercomments_r;
GRANT INSERT, UPDATE, DELETE ON usercomments.commentfile TO usercomments_w;

CREATE SEQUENCE usercomments.commentfile_pkseq START WITH 100000000 INCREMENT BY 10;
ALTER SEQUENCE usercomments.commentfile_pkseq OWNER TO userdb_owner;
GRANT USAGE, SELECT ON usercomments.commentfile_pkseq TO usercomments_r;

-------------------------------------------------------------------------

CREATE TABLE usercomments.commentreference (
  comment_reference_id BIGINT       NOT NULL,
  source_id            VARCHAR(100) NOT NULL,
  database_name        VARCHAR(15)  NOT NULL,
  comment_id           BIGINT       NOT NULL,
  CONSTRAINT comment_reference_key PRIMARY KEY (comment_reference_id),
  CONSTRAINT comment_id_ref_fkey FOREIGN KEY (comment_id)
    REFERENCES usercomments.comments(comment_id)
);

CREATE INDEX commentreference_idx01 ON usercomments.commentreference(comment_id);
CREATE INDEX commentreference_idx02 ON usercomments.commentreference(database_name, comment_id, source_id);

ALTER TABLE usercomments.commentreference OWNER TO userdb_owner;
GRANT SELECT ON usercomments.commentreference TO usercomments_r;
GRANT INSERT, UPDATE, DELETE ON usercomments.commentreference TO usercomments_w;

CREATE SEQUENCE usercomments.commentreference_pkseq START WITH 100000000 INCREMENT BY 10;
ALTER SEQUENCE usercomments.commentreference_pkseq OWNER TO userdb_owner;
GRANT USAGE, SELECT ON usercomments.commentreference_pkseq TO usercomments_r;

-------------------------------------------------------------------------

CREATE TABLE usercomments.commentsequence (
  comment_sequence_id BIGINT NOT NULL,
  sequence            TEXT   NOT NULL,
  comment_id          BIGINT NOT NULL,
  CONSTRAINT comment_sequence_key PRIMARY KEY (comment_sequence_id),
  CONSTRAINT comment_id_seq_fkey FOREIGN KEY (comment_id)
    REFERENCES usercomments.comments(comment_id)
);

CREATE INDEX commentsequence_idx01 ON usercomments.commentsequence(comment_id);

ALTER TABLE usercomments.commentsequence OWNER TO userdb_owner;
GRANT SELECT ON usercomments.commentsequence TO usercomments_r;
GRANT INSERT, UPDATE, DELETE ON usercomments.commentsequence TO usercomments_w;

CREATE SEQUENCE usercomments.commentsequence_pkseq START WITH 100000000 INCREMENT BY 10;
ALTER SEQUENCE usercomments.commentsequence_pkseq OWNER TO userdb_owner;
GRANT USAGE, SELECT ON usercomments.commentsequence_pkseq TO usercomments_r;

-------------------------------------------------------------------------

CREATE TABLE usercomments.commentstableid (
  comment_stable_id BIGINT       NOT NULL,
  stable_id         VARCHAR(200) NOT NULL,
  comment_id        BIGINT       NOT NULL,
  CONSTRAINT comment_stable_id_key PRIMARY KEY (comment_stable_id),
  CONSTRAINT comment_stable_id_fkey FOREIGN KEY (comment_id)
    REFERENCES usercomments.comments(comment_id)
);

CREATE INDEX commentstableid_idx01 ON usercomments.commentstableid(comment_id);
CREATE UNIQUE INDEX commentstableid_ux01 ON usercomments.commentstableid(stable_id, comment_id);

ALTER TABLE usercomments.commentstableid OWNER TO userdb_owner;
GRANT SELECT ON usercomments.commentstableid TO usercomments_r;
GRANT INSERT, UPDATE, DELETE ON usercomments.commentstableid TO usercomments_w;

CREATE SEQUENCE usercomments.commentstableid_pkseq START WITH 100000000 INCREMENT BY 10;
ALTER SEQUENCE usercomments.commentstableid_pkseq OWNER TO userdb_owner;
GRANT USAGE, SELECT ON usercomments.commentstableid_pkseq TO usercomments_r;

-------------------------------------------------------------------------

CREATE TABLE usercomments.commenttargetcategory (
  comment_target_category_id BIGINT NOT NULL,
  comment_id                 BIGINT NOT NULL,
  target_category_id         BIGINT NOT NULL,
  CONSTRAINT comment_target_category_key PRIMARY KEY (comment_target_category_id),
  CONSTRAINT comment_id_category_fkey FOREIGN KEY (comment_id)
    REFERENCES usercomments.comments(comment_id),
  CONSTRAINT target_category_id_fkey FOREIGN KEY (target_category_id)
    REFERENCES usercomments.targetcategory(target_category_id)
);

CREATE INDEX commenttargetcategory_idx01 ON usercomments.commenttargetcategory(comment_id);
CREATE INDEX commenttargetcategory_idx02 ON usercomments.commenttargetcategory(target_category_id);

ALTER TABLE usercomments.commenttargetcategory OWNER TO userdb_owner;
GRANT SELECT ON usercomments.commenttargetcategory TO usercomments_r;
GRANT INSERT, UPDATE, DELETE ON usercomments.commenttargetcategory TO usercomments_w;

CREATE SEQUENCE usercomments.commenttargetcategory_pkseq START WITH 100000000 INCREMENT BY 10;
ALTER SEQUENCE usercomments.commenttargetcategory_pkseq OWNER TO userdb_owner;

GRANT USAGE, SELECT ON usercomments.commenttargetcategory_pkseq TO usercomments_r;

-------------------------------------------------------------------------

CREATE TABLE usercomments.external_databases (
  external_database_id      BIGINT NOT NULL,
  external_database_name    VARCHAR(200),
  external_database_version VARCHAR(200),
  CONSTRAINT external_databases_pkey PRIMARY KEY (external_database_id)
);

ALTER TABLE usercomments.external_databases OWNER TO userdb_owner;
GRANT SELECT ON usercomments.external_databases TO usercomments_r;
GRANT INSERT, UPDATE, DELETE ON usercomments.external_databases TO usercomments_w;

CREATE SEQUENCE usercomments.external_databases_pkseq START WITH 100000000 INCREMENT BY 10;
ALTER SEQUENCE usercomments.external_databases_pkseq OWNER TO userdb_owner;
GRANT USAGE, SELECT ON usercomments.external_databases_pkseq TO usercomments_r;

-------------------------------------------------------------------------

CREATE TABLE usercomments.comment_external_database (
  external_database_id BIGINT NOT NULL,
  comment_id           BIGINT NOT NULL,
  CONSTRAINT comment_external_database_pkey PRIMARY KEY (external_database_id, comment_id),
  CONSTRAINT comment_id_fkey FOREIGN KEY (comment_id)
    REFERENCES usercomments.comments(comment_id),
  CONSTRAINT external_database_id_fkey FOREIGN KEY (external_database_id)
    REFERENCES usercomments.external_databases(external_database_id)
);


CREATE INDEX comment_edb_idx01 ON usercomments.comment_external_database(comment_id);

ALTER TABLE usercomments.comment_external_database OWNER TO userdb_owner;
GRANT SELECT ON usercomments.comment_external_database TO usercomments_r;
GRANT INSERT, UPDATE, DELETE ON usercomments.comment_external_database TO usercomments_w;

-------------------------------------------------------------------------

CREATE TABLE usercomments.locations (
  comment_id      BIGINT NOT NULL,
  location_id     BIGINT NOT NULL,
  location_start  NUMERIC(12),
  location_end    NUMERIC(12),
  coordinate_type VARCHAR(20),
  is_reverse      BOOLEAN,
  CONSTRAINT locations_pkey PRIMARY KEY (comment_id, location_id),
  CONSTRAINT locations_comment_id_fkey FOREIGN KEY (comment_id)
    REFERENCES usercomments.comments(comment_id)
);

ALTER TABLE usercomments.locations OWNER TO userdb_owner;
GRANT SELECT ON usercomments.locations TO usercomments_r;
GRANT INSERT, UPDATE, DELETE ON usercomments.locations TO usercomments_w;

CREATE SEQUENCE usercomments.locations_pkseq START WITH 100000000 INCREMENT BY 10;
ALTER SEQUENCE usercomments.locations_pkseq OWNER TO userdb_owner;
GRANT USAGE, SELECT ON usercomments.locations_pkseq TO usercomments_r;

-------------------------------------------------------------------------

CREATE TABLE usercomments.comment_users (
  user_id      BIGINT NOT NULL,
  first_name   VARCHAR(50),
  last_name    VARCHAR(50),
  organization VARCHAR(255),
  CONSTRAINT comment_users_pkey PRIMARY KEY (user_id),
  CONSTRAINT comment_users_user_id_fkey FOREIGN KEY (user_id)
    REFERENCES wdkuser.users(user_id)
);

ALTER TABLE usercomments.comment_users OWNER TO userdb_owner;
GRANT SELECT ON usercomments.comment_users TO usercomments_r;
GRANT INSERT, UPDATE, DELETE ON usercomments.comment_users TO usercomments_w;

-------------------------------------------------------------------------

-- view of comments with stable_id either as-is or mapped through commentStableId
CREATE OR REPLACE VIEW usercomments.mappedComment AS
SELECT c.comment_id
  , c.user_id
  , c.email
  , c.comment_date
  , c.comment_target_id
  , idMap.stable_id
  , c.conceptual
  , c.project_name
  , c.project_version
  , c.headline
  , c.review_status_id
  , c.accepted_version
  , c.location_string
  , c.organism
  , c.is_visible
FROM usercomments.comments c
   , (
       SELECT stable_id, comment_id
       FROM usercomments.comments
       UNION
       SELECT stable_id, comment_id
       FROM usercomments.commentStableId
     ) idMap
WHERE c.comment_id = idMap.comment_id;

ALTER VIEW usercomments.mappedComment OWNER TO userdb_owner;
GRANT SELECT ON usercomments.mappedComment TO usercomments_r;


/*==============================================================================
 * Pre-populate comment_target, targetcategory, and review_status with static values.
 * Note, the PK values don't matter for an empty target but they are kept like this
 * to make sure we can import data from an existing userdb.
 *============================================================================*/

-- Static values; new targets must be added manually
INSERT INTO usercomments.comment_target (comment_target_id, comment_target_name, require_location) VALUES('protein', 'Protein Sequence', false);
INSERT INTO usercomments.comment_target (comment_target_id, comment_target_name, require_location) VALUES('gene', 'Gene Feature', false);
INSERT INTO usercomments.comment_target (comment_target_id, comment_target_name, require_location) VALUES('genome', 'Genome Sequence', true);
INSERT INTO usercomments.comment_target (comment_target_id, comment_target_name, require_location) VALUES('isolate', 'Isolate Feature', false);
INSERT INTO usercomments.comment_target (comment_target_id, comment_target_name, require_location) VALUES('phenotype', 'Phenotype Feature', false);

-- Static values; new categories must be added manually
INSERT INTO usercomments.targetcategory (target_category_id, category, comment_target_id) VALUES(1, 'Gene Model', 'gene');
INSERT INTO usercomments.targetcategory (target_category_id, category, comment_target_id) VALUES(2, 'Name/Product', 'gene');
INSERT INTO usercomments.targetcategory (target_category_id, category, comment_target_id) VALUES(3, 'Function', 'gene');
INSERT INTO usercomments.targetcategory (target_category_id, category, comment_target_id) VALUES(4, 'Expression', 'gene');
INSERT INTO usercomments.targetcategory (target_category_id, category, comment_target_id) VALUES(5, 'Sequence', 'gene');
INSERT INTO usercomments.targetcategory (target_category_id, category, comment_target_id) VALUES(6, 'Phenotype', 'gene');

INSERT INTO usercomments.targetcategory (target_category_id, category, comment_target_id) VALUES(7, 'Characteristics/Overview', 'isolate');
INSERT INTO usercomments.targetcategory (target_category_id, category, comment_target_id) VALUES(8, 'Reference', 'isolate');
INSERT INTO usercomments.targetcategory (target_category_id, category, comment_target_id) VALUES(9, 'Sequence', 'isolate');

INSERT INTO usercomments.targetcategory (target_category_id, category, comment_target_id) VALUES(10, 'New Gene', 'genome');
INSERT INTO usercomments.targetcategory (target_category_id, category, comment_target_id) VALUES(11, 'New Feature', 'genome');
INSERT INTO usercomments.targetcategory (target_category_id, category, comment_target_id) VALUES(12, 'Centromere', 'genome');
INSERT INTO usercomments.targetcategory (target_category_id, category, comment_target_id) VALUES(13, 'Genomic Assembly', 'genome');
INSERT INTO usercomments.targetcategory (target_category_id, category, comment_target_id) VALUES(14, 'Sequence', 'genome');
INSERT INTO usercomments.targetcategory (target_category_id, category, comment_target_id) VALUES(33, 'Phenotype', 'genome');

INSERT INTO usercomments.targetcategory (target_category_id, category, comment_target_id) VALUES(15, 'Characteristics/Overview', 'snp');
INSERT INTO usercomments.targetcategory (target_category_id, category, comment_target_id) VALUES(16, 'Gene Context', 'snp');
INSERT INTO usercomments.targetcategory (target_category_id, category, comment_target_id) VALUES(17, 'Strains', 'snp');

INSERT INTO usercomments.targetcategory (target_category_id, category, comment_target_id) VALUES(19, 'Characteristics/Overview', 'est');
INSERT INTO usercomments.targetcategory (target_category_id, category, comment_target_id) VALUES(20, 'Alignment', 'est');
INSERT INTO usercomments.targetcategory (target_category_id, category, comment_target_id) VALUES(21, 'Sequence', 'est');
INSERT INTO usercomments.targetcategory (target_category_id, category, comment_target_id) VALUES(22, 'Assembly', 'est');

INSERT INTO usercomments.targetcategory (target_category_id, category, comment_target_id) VALUES(23, 'Characteristics/Overview', 'assembly');
INSERT INTO usercomments.targetcategory (target_category_id, category, comment_target_id) VALUES(24, 'Consensus Sequence', 'assembly');
INSERT INTO usercomments.targetcategory (target_category_id, category, comment_target_id) VALUES(25, 'Alignment', 'assembly');
INSERT INTO usercomments.targetcategory (target_category_id, category, comment_target_id) VALUES(26, 'Included Est''s', 'assembly');

INSERT INTO usercomments.targetcategory (target_category_id, category, comment_target_id) VALUES(27, 'Characteristics/Overview ', 'sage');
INSERT INTO usercomments.targetcategory (target_category_id, category, comment_target_id) VALUES(28, 'Gene', 'sage');
INSERT INTO usercomments.targetcategory (target_category_id, category, comment_target_id) VALUES(29, 'Alignment', 'sage');
INSERT INTO usercomments.targetcategory (target_category_id, category, comment_target_id) VALUES(30, 'Library Counts', 'sage');

INSERT INTO usercomments.targetcategory (target_category_id, category, comment_target_id) VALUES(31, 'Alignment', 'orf');
INSERT INTO usercomments.targetcategory (target_category_id, category, comment_target_id) VALUES(32, 'Sequence', 'orf');

-- Static values; new statuses must be added manually
INSERT INTO usercomments.review_status (review_status_id, review_status_name) VALUES('task',      'the comment is an assigned task');
INSERT INTO usercomments.review_status (review_status_id, review_status_name) VALUES('accepted',  'the comment has been reviewed and accepted');
INSERT INTO usercomments.review_status (review_status_id, review_status_name) VALUES('rejected',  'the comment has been reviewed and rejected');
INSERT INTO usercomments.review_status (review_status_id, review_status_name) VALUES('unknown',   'the comment has not been reviewed (by default)');
INSERT INTO usercomments.review_status (review_status_id, review_status_name) VALUES('not_spam',  'the comment has been reviewed internally, and determined not a spam');
INSERT INTO usercomments.review_status (review_status_id, review_status_name) VALUES('spam',      'the comment has been reviewed internally, and determined as a spam');
INSERT INTO usercomments.review_status (review_status_id, review_status_name) VALUES('adopted',   'the comment has been adopted by the sequencing center');
INSERT INTO usercomments.review_status (review_status_id, review_status_name) VALUES('community', 'community expert annotation');
