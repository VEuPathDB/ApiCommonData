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

INSERT INTO comments2.TargetCategory (target_category_id, category, comment_target_id) VALUES(1, 'model', 'gene');
INSERT INTO comments2.TargetCategory (target_category_id, category, comment_target_id) VALUES(2, 'name', 'gene');
INSERT INTO comments2.TargetCategory (target_category_id, category, comment_target_id) VALUES(3, 'function', 'gene');
INSERT INTO comments2.TargetCategory (target_category_id, category, comment_target_id) VALUES(4, 'expression', 'gene');
INSERT INTO comments2.TargetCategory (target_category_id, category, comment_target_id) VALUES(5, 'sequence', 'gene');
INSERT INTO comments2.TargetCategory (target_category_id, category, comment_target_id) VALUES(6, 'other', 'gene');

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
