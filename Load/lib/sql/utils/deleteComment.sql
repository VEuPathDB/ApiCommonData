-- deleteComment.sql
--
-- delete records with the given comment ID from the Comments, CommentStableId, CommentTargetCategory, Comment_External_Database, and Locations
--
-- usage: sqlplus <user>@apicomm @deleteComment <commentId>
--
-- USE THIS SCRIPT WITH CAUTION

set verify off pagesize 50000

prompt deleting comment ID &1:
select * from comments2.Comments where comment_id = &1;

prompt Locations
delete from comments2.Locations where comment_id = &1;

prompt Comment_External_Database
delete from comments2.Comment_External_Database where comment_id = &1;

prompt CommentTargetCategory
delete from comments2.CommentTargetCategory where comment_id = &1;

prompt CommentStableId
delete from comments2.CommentStableId where comment_id = &1;

prompt CommentReference
delete from comments2.CommentReference where comment_id = &1;

prompt CommentFile
delete from comments2.CommentFile where comment_id = &1;

prompt Comments
delete from comments2.Comments where comment_id = &1;

exit
