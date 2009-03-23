DROP TABLE comments2.CommentStableId
DROP TABLE comments2.CommentFile;
DROP TABLE comments2.CommentTargetCategory;
DROP TABLE comments2.TargetCategory;
DROP TABLE comments2.CommentReference;

DROP SEQUENCE comments2.commentStableId_pkseq; 
DROP SEQUENCE comments2.commentTargetCategory_pkseq; 
DROP SEQUENCE comments2.commentReference_pkseq; 
DROP SEQUENCE comments2.commentFile_pkseq; 

CREATE TABLE comments2.TargetCategory
(
  target_category_id NUMBER(10) NOT NULL,
  category VARCHAR2(100) NOT NULL,
	comment_target_id varchar(20) NOT NULL,
	CONSTRAINT target_category_key PRIMARY KEY (target_category_id)
);

GRANT insert, update, delete on comments2.TargetCategory to GUS_W;
GRANT select on comments2.TargetCategory to GUS_R;

INSERT INTO comments2.TargetCategory (target_category_id, category, comment_target_id) VALUES(1, 'Gene Model', 'gene');
INSERT INTO comments2.TargetCategory (target_category_id, category, comment_target_id) VALUES(2, 'Name/Product', 'gene');
INSERT INTO comments2.TargetCategory (target_category_id, category, comment_target_id) VALUES(3, 'Function', 'gene');
INSERT INTO comments2.TargetCategory (target_category_id, category, comment_target_id) VALUES(4, 'Expression', 'gene');
INSERT INTO comments2.TargetCategory (target_category_id, category, comment_target_id) VALUES(5, 'Sequence', 'gene');
INSERT INTO comments2.TargetCategory (target_category_id, category, comment_target_id) VALUES(6, 'other', 'gene');

INSERT INTO comments2.TargetCategory (target_category_id, category, comment_target_id) VALUES(7, 'Characteristics/Overview', 'isolate');
INSERT INTO comments2.TargetCategory (target_category_id, category, comment_target_id) VALUES(8, 'Reference', 'isolate');
INSERT INTO comments2.TargetCategory (target_category_id, category, comment_target_id) VALUES(9, 'Sequence', 'isolate');

INSERT INTO comments2.TargetCategory (target_category_id, category, comment_target_id) VALUES(10, 'New Gene', 'genome');
INSERT INTO comments2.TargetCategory (target_category_id, category, comment_target_id) VALUES(11, 'New Feature', 'genome');
INSERT INTO comments2.TargetCategory (target_category_id, category, comment_target_id) VALUES(12, 'Centromere', 'genome');
INSERT INTO comments2.TargetCategory (target_category_id, category, comment_target_id) VALUES(13, 'Genomic Assembly', 'genome');
INSERT INTO comments2.TargetCategory (target_category_id, category, comment_target_id) VALUES(14, 'Sequence', 'genome');

INSERT INTO comments2.TargetCategory (target_category_id, category, comment_target_id) VALUES(15, 'Characteristics/Overview', 'snp');
INSERT INTO comments2.TargetCategory (target_category_id, category, comment_target_id) VALUES(16, 'Gene Context', 'snp');
INSERT INTO comments2.TargetCategory (target_category_id, category, comment_target_id) VALUES(17, 'Strains', 'snp');

INSERT INTO comments2.TargetCategory (target_category_id, category, comment_target_id) VALUES(19, 'Characteristics/Overview', 'est');
INSERT INTO comments2.TargetCategory (target_category_id, category, comment_target_id) VALUES(20, 'Alignment', 'est');
INSERT INTO comments2.TargetCategory (target_category_id, category, comment_target_id) VALUES(21, 'Sequence', 'est');
INSERT INTO comments2.TargetCategory (target_category_id, category, comment_target_id) VALUES(22, 'Assembly', 'est');

INSERT INTO comments2.TargetCategory (target_category_id, category, comment_target_id) VALUES(23, 'Characteristics/Overview', 'assembly');
INSERT INTO comments2.TargetCategory (target_category_id, category, comment_target_id) VALUES(24, 'Consensus Sequence', 'assembly');
INSERT INTO comments2.TargetCategory (target_category_id, category, comment_target_id) VALUES(25, 'Alignment', 'assembly');
INSERT INTO comments2.TargetCategory (target_category_id, category, comment_target_id) VALUES(26, 'Included Est''s', 'assembly');

INSERT INTO comments2.TargetCategory (target_category_id, category, comment_target_id) VALUES(27, 'Characteristics/Overview ', 'sage');
INSERT INTO comments2.TargetCategory (target_category_id, category, comment_target_id) VALUES(28, 'Gene', 'sage');
INSERT INTO comments2.TargetCategory (target_category_id, category, comment_target_id) VALUES(29, 'Alignment', 'sage');
INSERT INTO comments2.TargetCategory (target_category_id, category, comment_target_id) VALUES(30, 'Library Counts', 'sage');

INSERT INTO comments2.TargetCategory (target_category_id, category, comment_target_id) VALUES(31, 'Alignment', 'orf');
INSERT INTO comments2.TargetCategory (target_category_id, category, comment_target_id) VALUES(32, 'Sequence', 'orf');


CREATE TABLE comments2.CommentTargetCategory
(
  comment_target_category_id NUMBER(10) NOT NULL,
	comment_id NUMBER(10) NOT NULL,
  target_category_id NUMBER(10) NOT NULL,
	CONSTRAINT comment_target_category_key PRIMARY KEY (comment_target_category_id),
	CONSTRAINT comment_id_category_fkey FOREIGN KEY (comment_id)
	   REFERENCES comments2.comments (comment_id),
	CONSTRAINT target_category_id_fkey FOREIGN KEY (target_category_id)
	   REFERENCES comments2.TargetCategory (target_category_id)
);

GRANT insert, update, delete on comments2.CommentTargetCategory to GUS_W;
GRANT select on comments2.CommentTargetCategory to GUS_R;

CREATE SEQUENCE comments2.commentTargetCategory_pkseq START WITH 1 INCREMENT BY 1;

GRANT select on comments2.commentTargetCategory_pkseq to GUS_W;
GRANT select on comments2.commentTargetCategory_pkseq to GUS_R;

CREATE TABLE comments2.CommentReference
(
  comment_reference_id NUMBER(10) NOT NULL,
	source_id VARCHAR2(15) NOT NULL,
	database_name VARCHAR2(15) NOT NULL,
  comment_id NUMBER(10) NOT NULL,
	CONSTRAINT comment_reference_key PRIMARY KEY (comment_reference_id),
	CONSTRAINT comment_id_ref_fkey FOREIGN KEY (comment_id)
	   REFERENCES comments2.comments (comment_id)
);

GRANT insert, update, delete on comments2.CommentReference to GUS_W;
GRANT select on comments2.CommentReference to GUS_R;

CREATE SEQUENCE comments2.commentReference_pkseq START WITH 1 INCREMENT BY 1;
GRANT select on comments2.commentReference_pkseq to GUS_W;
GRANT select on comments2.commentReference_pkseq to GUS_R;

CREATE TABLE comments2.CommentFile
(
  file_id NUMBER(10) NOT NULL,
	uri VARCHAR2(500) NOT NULL,
  comment_id NUMBER(10) NOT NULL,
	CONSTRAINT file_id_key PRIMARY KEY (file_id),
	CONSTRAINT comment_id_file_fkey FOREIGN KEY (comment_id)
	   REFERENCES comments2.comments (comment_id)
);

GRANT insert, update, delete on comments2.CommentFile to GUS_W;
GRANT select on comments2.CommentFile to GUS_R;

CREATE SEQUENCE comments2.commentFile_pkseq START WITH 1 INCREMENT BY 1;
GRANT select on comments2.commentFile_pkseq to GUS_W;
GRANT select on comments2.commentFile_pkseq to GUS_R;

CREATE TABLE comments2.CommentStableId
(
  comment_stable_id NUMBER(10) NOT NULL,
  stable_id VARCHAR2(200) NOT NULL,
  comment_id NUMBER(10) NOT NULL,
	CONSTRAINT comment_stable_id_key PRIMARY KEY (comment_stable_id),
	CONSTRAINT comment_stable_id_fkey FOREIGN KEY (comment_id)
	   REFERENCES comments2.comments (comment_id)
);

GRANT insert, update, delete on comments2.CommentStableId to GUS_W;
GRANT select on comments2.CommentStableId to GUS_R;

CREATE SEQUENCE comments2.commentStableId_pkseq START WITH 1 INCREMENT BY 1;
GRANT select on comments2.commentStableId_pkseq to GUS_W;
GRANT select on comments2.commentStableId_pkseq to GUS_R;
