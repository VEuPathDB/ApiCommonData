DROP TABLE userlogins5.CommentStableId;
DROP TABLE userlogins5.CommentFile;
DROP TABLE userlogins5.CommentTargetCategory;
DROP TABLE userlogins5.TargetCategory;
DROP TABLE userlogins5.CommentReference;
DROP TABLE userlogins5.CommentSequence;

DROP SEQUENCE userlogins5.commentStableId_pkseq; 
DROP SEQUENCE userlogins5.commentTargetCategory_pkseq; 
DROP SEQUENCE userlogins5.commentReference_pkseq; 
DROP SEQUENCE userlogins5.commentFile_pkseq; 
DROP SEQUENCE userlogins5.commentSequence_pkseq; 

CREATE TABLE userlogins5.TargetCategory
(
  target_category_id NUMERIC(10) NOT NULL,
  category VARCHAR(100) NOT NULL,
  comment_target_id varchar(20) NOT NULL,
  CONSTRAINT target_category_key PRIMARY KEY (target_category_id)
);

GRANT insert, update, delete on userlogins5.TargetCategory to GUS_W;
GRANT select on userlogins5.TargetCategory to GUS_R;

INSERT INTO userlogins5.TargetCategory (target_category_id, category, comment_target_id) VALUES(1, 'Gene Model', 'gene');
INSERT INTO userlogins5.TargetCategory (target_category_id, category, comment_target_id) VALUES(2, 'Name/Product', 'gene');
INSERT INTO userlogins5.TargetCategory (target_category_id, category, comment_target_id) VALUES(3, 'Function', 'gene');
INSERT INTO userlogins5.TargetCategory (target_category_id, category, comment_target_id) VALUES(4, 'Expression', 'gene');
INSERT INTO userlogins5.TargetCategory (target_category_id, category, comment_target_id) VALUES(5, 'Sequence', 'gene');
INSERT INTO userlogins5.TargetCategory (target_category_id, category, comment_target_id) VALUES(6, 'Phenotype', 'gene');

INSERT INTO userlogins5.TargetCategory (target_category_id, category, comment_target_id) VALUES(7, 'Characteristics/Overview', 'isolate');
INSERT INTO userlogins5.TargetCategory (target_category_id, category, comment_target_id) VALUES(8, 'Reference', 'isolate');
INSERT INTO userlogins5.TargetCategory (target_category_id, category, comment_target_id) VALUES(9, 'Sequence', 'isolate');

INSERT INTO userlogins5.TargetCategory (target_category_id, category, comment_target_id) VALUES(10, 'New Gene', 'genome');
INSERT INTO userlogins5.TargetCategory (target_category_id, category, comment_target_id) VALUES(11, 'New Feature', 'genome');
INSERT INTO userlogins5.TargetCategory (target_category_id, category, comment_target_id) VALUES(12, 'Centromere', 'genome');
INSERT INTO userlogins5.TargetCategory (target_category_id, category, comment_target_id) VALUES(13, 'Genomic Assembly', 'genome');
INSERT INTO userlogins5.TargetCategory (target_category_id, category, comment_target_id) VALUES(14, 'Sequence', 'genome');
INSERT INTO userlogins5.TargetCategory (target_category_id, category, comment_target_id) VALUES(33, 'Phenotype', 'genome');

INSERT INTO userlogins5.TargetCategory (target_category_id, category, comment_target_id) VALUES(15, 'Characteristics/Overview', 'snp');
INSERT INTO userlogins5.TargetCategory (target_category_id, category, comment_target_id) VALUES(16, 'Gene Context', 'snp');
INSERT INTO userlogins5.TargetCategory (target_category_id, category, comment_target_id) VALUES(17, 'Strains', 'snp');

INSERT INTO userlogins5.TargetCategory (target_category_id, category, comment_target_id) VALUES(19, 'Characteristics/Overview', 'est');
INSERT INTO userlogins5.TargetCategory (target_category_id, category, comment_target_id) VALUES(20, 'Alignment', 'est');
INSERT INTO userlogins5.TargetCategory (target_category_id, category, comment_target_id) VALUES(21, 'Sequence', 'est');
INSERT INTO userlogins5.TargetCategory (target_category_id, category, comment_target_id) VALUES(22, 'Assembly', 'est');

INSERT INTO userlogins5.TargetCategory (target_category_id, category, comment_target_id) VALUES(23, 'Characteristics/Overview', 'assembly');
INSERT INTO userlogins5.TargetCategory (target_category_id, category, comment_target_id) VALUES(24, 'Consensus Sequence', 'assembly');
INSERT INTO userlogins5.TargetCategory (target_category_id, category, comment_target_id) VALUES(25, 'Alignment', 'assembly');
INSERT INTO userlogins5.TargetCategory (target_category_id, category, comment_target_id) VALUES(26, 'Included Est''s', 'assembly');

INSERT INTO userlogins5.TargetCategory (target_category_id, category, comment_target_id) VALUES(27, 'Characteristics/Overview ', 'sage');
INSERT INTO userlogins5.TargetCategory (target_category_id, category, comment_target_id) VALUES(28, 'Gene', 'sage');
INSERT INTO userlogins5.TargetCategory (target_category_id, category, comment_target_id) VALUES(29, 'Alignment', 'sage');
INSERT INTO userlogins5.TargetCategory (target_category_id, category, comment_target_id) VALUES(30, 'Library Counts', 'sage');

INSERT INTO userlogins5.TargetCategory (target_category_id, category, comment_target_id) VALUES(31, 'Alignment', 'orf');
INSERT INTO userlogins5.TargetCategory (target_category_id, category, comment_target_id) VALUES(32, 'Sequence', 'orf');


CREATE TABLE userlogins5.CommentTargetCategory
(
  comment_target_category_id NUMERIC(10) NOT NULL,
  comment_id NUMERIC(10) NOT NULL,
  target_category_id NUMERIC(10) NOT NULL,
  CONSTRAINT comment_target_category_key PRIMARY KEY (comment_target_category_id),
  CONSTRAINT comment_id_category_fkey FOREIGN KEY (comment_id)
     REFERENCES userlogins5.comments (comment_id),
  CONSTRAINT target_category_id_fkey FOREIGN KEY (target_category_id)
     REFERENCES userlogins5.TargetCategory (target_category_id)
);

CREATE INDEX CommentTargetCategory_idx01 ON userlogins5.CommentTargetCategory (comment_id);
CREATE INDEX CommentTargetCategory_idx02 ON userlogins5.CommentTargetCategory (target_category_id);


GRANT insert, update, delete on userlogins5.CommentTargetCategory to GUS_W;
GRANT select on userlogins5.CommentTargetCategory to GUS_R;

CREATE SEQUENCE userlogins5.commentTargetCategory_pkseq START WITH 1 INCREMENT BY 1;

GRANT select on userlogins5.commentTargetCategory_pkseq to GUS_W;
GRANT select on userlogins5.commentTargetCategory_pkseq to GUS_R;

CREATE TABLE userlogins5.CommentReference
(
  comment_reference_id NUMERIC(10) NOT NULL,
  source_id VARCHAR(100) NOT NULL,
  database_name VARCHAR(15) NOT NULL,
  comment_id NUMERIC(10) NOT NULL,
  CONSTRAINT comment_reference_key PRIMARY KEY (comment_reference_id),
  CONSTRAINT comment_id_ref_fkey FOREIGN KEY (comment_id)
     REFERENCES userlogins5.comments (comment_id)
);

CREATE INDEX CommentReference_idx01 ON userlogins5.CommentReference (comment_id);
CREATE INDEX CommentReference_idx02 ON userlogins5.CommentReference (database_name, comment_id, source_id);


GRANT insert, update, delete on userlogins5.CommentReference to GUS_W;
GRANT select on userlogins5.CommentReference to GUS_R;

CREATE SEQUENCE userlogins5.commentReference_pkseq START WITH 1 INCREMENT BY 1;
GRANT select on userlogins5.commentReference_pkseq to GUS_W;
GRANT select on userlogins5.commentReference_pkseq to GUS_R;

CREATE TABLE userlogins5.CommentSequence
(
  comment_sequence_id NUMERIC(10) NOT NULL,
  sequence TEXT NOT NULL,
  comment_id NUMERIC(10) NOT NULL,
  CONSTRAINT comment_sequence_key PRIMARY KEY (comment_sequence_id),
  CONSTRAINT comment_id_seq_fkey FOREIGN KEY (comment_id)
     REFERENCES userlogins5.comments (comment_id)
);

CREATE INDEX CommentSequence_idx01 ON userlogins5.CommentSequence (comment_id);

GRANT insert, update, delete on userlogins5.CommentSequence to GUS_W;
GRANT select on userlogins5.CommentSequence to GUS_R;

CREATE SEQUENCE userlogins5.commentSequence_pkseq START WITH 1 INCREMENT BY 1;
GRANT select on userlogins5.commentSequence_pkseq to GUS_W;
GRANT select on userlogins5.commentSequence_pkseq to GUS_R;

CREATE TABLE userlogins5.CommentFile
(
  file_id NUMERIC(10) NOT NULL,
  name VARCHAR(500) NOT NULL,
  notes VARCHAR(4000) NOT NULL,
  comment_id NUMERIC(10) NOT NULL,
  CONSTRAINT file_id_key PRIMARY KEY (file_id),
  CONSTRAINT comment_id_file_fkey FOREIGN KEY (comment_id)
     REFERENCES userlogins5.comments (comment_id)
);

CREATE INDEX CommentFile_idx01 ON userlogins5.CommentFile (comment_id, file_id);

GRANT insert, update, delete on userlogins5.CommentFile to GUS_W;
GRANT select on userlogins5.CommentFile to GUS_R;

CREATE SEQUENCE userlogins5.commentFile_pkseq START WITH 1 INCREMENT BY 1;
GRANT select on userlogins5.commentFile_pkseq to GUS_W;
GRANT select on userlogins5.commentFile_pkseq to GUS_R;

CREATE TABLE userlogins5.CommentStableId
(
  comment_stable_id NUMERIC(10) NOT NULL,
  stable_id VARCHAR(200) NOT NULL,
  comment_id NUMERIC(10) NOT NULL,
  CONSTRAINT comment_stable_id_key PRIMARY KEY (comment_stable_id),
  CONSTRAINT comment_stable_id_fkey FOREIGN KEY (comment_id)
     REFERENCES userlogins5.comments (comment_id)
);

CREATE INDEX CommentStableId_idx01 ON userlogins5.CommentStableId (comment_id);
CREATE UNIQUE INDEX CommentStableId_ux01 ON userlogins5.CommentStableId (stable_id, comment_id);

GRANT insert, update, delete on userlogins5.CommentStableId to GUS_W;
GRANT select on userlogins5.CommentStableId to GUS_R;

CREATE SEQUENCE userlogins5.commentStableId_pkseq START WITH 1 INCREMENT BY 1;
GRANT select on userlogins5.commentStableId_pkseq to GUS_W;
GRANT select on userlogins5.commentStableId_pkseq to GUS_R;
