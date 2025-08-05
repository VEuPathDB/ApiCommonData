
DROP VIEW usercomments.mappedcomment;

DROP INDEX comment_edb_idx01;
DROP INDEX comments_idx02;
DROP INDEX comments_idx03;
DROP INDEX comments_ux01;
DROP INDEX comments_ux02;
DROP INDEX commentfile_idx01

DROP TABLE usercomments.commentfile;
DROP TABLE usercomments.targetcategory;
DROP TABLE usercomments.comment_external_database;
DROP TABLE usercomments.commentreference;
DROP TABLE usercomments.comments;
DROP TABLE usercomments.commentsequence;
DROP TABLE usercomments.commentstableid;
DROP TABLE usercomments.comment_users;
DROP TABLE usercomments.comment_target;
DROP TABLE usercomments.external_databases;
DROP TABLE usercomments.locations;
DROP TABLE usercomments.review_status;
DROP TABLE usercomments.commenttargetcategory;

DROP SEQUENCE usercomments.commentfile_pkseq;
DROP SEQUENCE usercomments.commentreference_pkseq;
DROP SEQUENCE usercomments.commentsequence_pkseq;
DROP SEQUENCE usercomments.comments_pkseq;
DROP SEQUENCE usercomments.commentstableId_pkseq;
DROP SEQUENCE usercomments.external_databases_pkseq;
DROP SEQUENCE usercomments.locations_pkseq;
