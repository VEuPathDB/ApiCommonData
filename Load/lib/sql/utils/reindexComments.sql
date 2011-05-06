-- reindexComments.sql
--
-- delete and reload all the records in apidb.TextSearchableComment. This may be
-- useful to capture updates to comment records. (Comments2.comments and 
-- comments2.CommentStableId have insert triggers to index new data, but not
-- update or delete triggers.)

select count(*) "starting" from apidb.TextSearchableComment;

delete from apidb.TextSearchableComment;

select count(*) "after delete" from apidb.TextSearchableComment;

exec apidb.move_comments

select count(*) "after move_comments" from apidb.TextSearchableComment;

exit
