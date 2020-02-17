DROP TABLE userlogins5.comment_target;
DROP TABLE userlogins5.comment_file;
DROP TABLE userlogins5.CommentTargetCategory;
DROP TABLE userlogins5.TargetCategory;
DROP TABLE userlogins5.comment_reference;
DROP TABLE userlogins5.comment_sequence;

DROP SEQUENCE userlogins5.commentStableId_pkseq;
DROP SEQUENCE userlogins5.commentReference_pkseq;
DROP SEQUENCE userlogins5.commentFile_pkseq;
DROP SEQUENCE userlogins5.commentSequence_pkseq;

--
-- Comment Target Category
--

CREATE TABLE userlogins5.comment_target_category
(
  comment_target_category_id NUMBER(10) NOT NULL,
  category                   VARCHAR2(100) NOT NULL,
  comment_target_type        VARCHAR(20) NOT NULL,
  CONSTRAINT target_category_key PRIMARY KEY (comment_target_category_id)
);

GRANT insert, update, delete on userlogins5.comment_target_category to GUS_W;
GRANT select on userlogins5.comment_target_category to GUS_R;

INSERT INTO userlogins5.comment_target_category (comment_target_category_id, category, comment_target_type) VALUES(1, 'Gene Model', 'gene');
INSERT INTO userlogins5.comment_target_category (comment_target_category_id, category, comment_target_type) VALUES(2, 'Name/Product', 'gene');
INSERT INTO userlogins5.comment_target_category (comment_target_category_id, category, comment_target_type) VALUES(3, 'Function', 'gene');
INSERT INTO userlogins5.comment_target_category (comment_target_category_id, category, comment_target_type) VALUES(4, 'Expression', 'gene');
INSERT INTO userlogins5.comment_target_category (comment_target_category_id, category, comment_target_type) VALUES(5, 'Sequence', 'gene');
INSERT INTO userlogins5.comment_target_category (comment_target_category_id, category, comment_target_type) VALUES(6, 'Phenotype', 'gene');

INSERT INTO userlogins5.comment_target_category (comment_target_category_id, category, comment_target_type) VALUES(7, 'Characteristics/Overview', 'isolate');
INSERT INTO userlogins5.comment_target_category (comment_target_category_id, category, comment_target_type) VALUES(8, 'Reference', 'isolate');
INSERT INTO userlogins5.comment_target_category (comment_target_category_id, category, comment_target_type) VALUES(9, 'Sequence', 'isolate');

INSERT INTO userlogins5.comment_target_category (comment_target_category_id, category, comment_target_type) VALUES(10, 'New Gene', 'genome');
INSERT INTO userlogins5.comment_target_category (comment_target_category_id, category, comment_target_type) VALUES(11, 'New Feature', 'genome');
INSERT INTO userlogins5.comment_target_category (comment_target_category_id, category, comment_target_type) VALUES(12, 'Centromere', 'genome');
INSERT INTO userlogins5.comment_target_category (comment_target_category_id, category, comment_target_type) VALUES(13, 'Genomic Assembly', 'genome');
INSERT INTO userlogins5.comment_target_category (comment_target_category_id, category, comment_target_type) VALUES(14, 'Sequence', 'genome');
INSERT INTO userlogins5.comment_target_category (comment_target_category_id, category, comment_target_type) VALUES(33, 'Phenotype', 'genome');

INSERT INTO userlogins5.comment_target_category (comment_target_category_id, category, comment_target_type) VALUES(15, 'Characteristics/Overview', 'snp');
INSERT INTO userlogins5.comment_target_category (comment_target_category_id, category, comment_target_type) VALUES(16, 'Gene Context', 'snp');
INSERT INTO userlogins5.comment_target_category (comment_target_category_id, category, comment_target_type) VALUES(17, 'Strains', 'snp');

INSERT INTO userlogins5.comment_target_category (comment_target_category_id, category, comment_target_type) VALUES(19, 'Characteristics/Overview', 'est');
INSERT INTO userlogins5.comment_target_category (comment_target_category_id, category, comment_target_type) VALUES(20, 'Alignment', 'est');
INSERT INTO userlogins5.comment_target_category (comment_target_category_id, category, comment_target_type) VALUES(21, 'Sequence', 'est');
INSERT INTO userlogins5.comment_target_category (comment_target_category_id, category, comment_target_type) VALUES(22, 'Assembly', 'est');

INSERT INTO userlogins5.comment_target_category (comment_target_category_id, category, comment_target_type) VALUES(23, 'Characteristics/Overview', 'assembly');
INSERT INTO userlogins5.comment_target_category (comment_target_category_id, category, comment_target_type) VALUES(24, 'Consensus Sequence', 'assembly');
INSERT INTO userlogins5.comment_target_category (comment_target_category_id, category, comment_target_type) VALUES(25, 'Alignment', 'assembly');
INSERT INTO userlogins5.comment_target_category (comment_target_category_id, category, comment_target_type) VALUES(26, 'Included Est''s', 'assembly');

INSERT INTO userlogins5.comment_target_category (comment_target_category_id, category, comment_target_type) VALUES(27, 'Characteristics/Overview ', 'sage');
INSERT INTO userlogins5.comment_target_category (comment_target_category_id, category, comment_target_type) VALUES(28, 'Gene', 'sage');
INSERT INTO userlogins5.comment_target_category (comment_target_category_id, category, comment_target_type) VALUES(29, 'Alignment', 'sage');
INSERT INTO userlogins5.comment_target_category (comment_target_category_id, category, comment_target_type) VALUES(30, 'Library Counts', 'sage');

INSERT INTO userlogins5.comment_target_category (comment_target_category_id, category, comment_target_type) VALUES(31, 'Alignment', 'orf');
INSERT INTO userlogins5.comment_target_category (comment_target_category_id, category, comment_target_type) VALUES(32, 'Sequence', 'orf');

--
-- Comment to Comment Target Category
--

CREATE TABLE userlogins5.comment_comment_target_category
(
  comment_id NUMBER(10) NOT NULL,
  comment_target_category_id NUMBER(10) NOT NULL,
  CONSTRAINT comment_id_category_fkey FOREIGN KEY (comment_id)
     REFERENCES userlogins5.comments (comment_id),
  CONSTRAINT target_category_id_fkey FOREIGN KEY (comment_target_category_id)
     REFERENCES userlogins5.TargetCategory (comment_target_category_id)
);

CREATE INDEX userlogins5.comment_comment_target_category_idx01 ON userlogins5.comment_comment_target_category (comment_id);
CREATE INDEX userlogins5.comment_comment_target_category_idx02 ON userlogins5.comment_comment_target_category (comment_target_category_id);

GRANT insert, update, delete on userlogins5.comment_comment_target_category to GUS_W;
GRANT select on userlogins5.comment_comment_target_category to GUS_R;

--
-- Comment Reference
--

CREATE TABLE userlogins5.comment_reference
(
  comment_reference_id NUMBER(10) NOT NULL,
  source_id VARCHAR2(100) NOT NULL,
  database_name VARCHAR2(15) NOT NULL,
  comment_id NUMBER(10) NOT NULL,
  CONSTRAINT comment_reference_key PRIMARY KEY (comment_reference_id),
  CONSTRAINT comment_id_ref_fkey FOREIGN KEY (comment_id)
     REFERENCES userlogins5.comments (comment_id)
);

CREATE INDEX userlogins5.comment_reference_idx01 ON userlogins5.comment_reference (comment_id);
CREATE INDEX userlogins5.comment_reference_idx02 ON userlogins5.comment_reference (database_name, comment_id, source_id);

GRANT insert, update, delete on userlogins5.comment_reference to GUS_W;
GRANT select on userlogins5.comment_reference to GUS_R;

-- TODO: Find references.
-- TODO: Are these needed?
CREATE SEQUENCE userlogins5.commentReference_pkseq START WITH 1 INCREMENT BY 1;
GRANT select on userlogins5.commentReference_pkseq to GUS_W;
GRANT select on userlogins5.commentReference_pkseq to GUS_R;

--
-- Comment Sequence
--

CREATE TABLE userlogins5.comment_sequence
(
  comment_sequence_id NUMBER(10) NOT NULL,
  sequence CLOB NOT NULL,
  comment_id NUMBER(10) NOT NULL,
  CONSTRAINT comment_sequence_key PRIMARY KEY (comment_sequence_id),
  CONSTRAINT comment_id_seq_fkey FOREIGN KEY (comment_id)
     REFERENCES userlogins5.comments (comment_id)
);

CREATE INDEX userlogins5.comment_sequence_idx01 ON userlogins5.comment_sequence (comment_id);

GRANT insert, update, delete on userlogins5.comment_sequence to GUS_W;
GRANT select on userlogins5.comment_sequence to GUS_R;

-- TODO: Find references.
-- TODO: Are these needed?
CREATE SEQUENCE userlogins5.commentSequence_pkseq START WITH 1 INCREMENT BY 1;
GRANT select on userlogins5.commentSequence_pkseq to GUS_W;
GRANT select on userlogins5.commentSequence_pkseq to GUS_R;

--
-- Comment File
--

CREATE TABLE userlogins5.comment_file
(
  file_id NUMBER(10) NOT NULL,
  name VARCHAR2(500) NOT NULL,
  notes VARCHAR2(4000) NOT NULL,
  comment_id NUMBER(10) NOT NULL,
  CONSTRAINT file_id_key PRIMARY KEY (file_id),
  CONSTRAINT comment_id_file_fkey FOREIGN KEY (comment_id)
     REFERENCES userlogins5.comments (comment_id)
);

CREATE INDEX userlogins5.comment_file_idx01 ON userlogins5.comment_file (comment_id, file_id);

GRANT insert, update, delete on userlogins5.comment_file to GUS_W;
GRANT select on userlogins5.comment_file to GUS_R;

-- TODO: Find references.
CREATE SEQUENCE userlogins5.commentFile_pkseq START WITH 1 INCREMENT BY 1;
GRANT select on userlogins5.commentFile_pkseq to GUS_W;
GRANT select on userlogins5.commentFile_pkseq to GUS_R;

--
-- Comment Target
--

-- TODO: Why is comment id not a foreign key?
CREATE TABLE userlogins5.comment_target
(
  stable_id VARCHAR2(200) NOT NULL,
  comment_id NUMBER(10) NOT NULL,
  is_primary_target NUMBER(1) DEFAULT 0 NOT NULL
);

CREATE INDEX userlogins5.comment_target_idx01 ON userlogins5.comment_target (comment_id);
CREATE UNIQUE INDEX userlogins5.comment_target_ux01 ON userlogins5.comment_target (stable_id, comment_id);
CREATE UNIQUE INDEX comment_target_id_one_primary
  ON userlogins5.comment_target (
    CASE
      WHEN is_primary_target = 1
        THEN comment_id
      ELSE NULL
    END
  );

GRANT insert, update, delete on userlogins5.comment_target to GUS_W;
GRANT select on userlogins5.comment_target to GUS_R;
