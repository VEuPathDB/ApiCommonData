-- reindexComments.sql
--
-- truncate and reload apidb.TextSearchableComment. This will ensure that it is
-- in sync with the Comments / CommentStableId / CommentReference tables, which
-- are the primary home of comments. (We can't simply point text search at those
-- because Oracle Text wants to index and search a single column.)

-- In the past, it was necessary to do this from time to time to bring
-- TextSearchableComment back into sync because the triggers on the comments
-- tables did not handle updates or deletes. We're installing triggers that do,
-- but keeping this script around for the transition and as a fallback.

-- Note that the expression SELECTed into TextSearchableComment must be kept in
-- sync with those in the triggers, which live in searchableCommentText.sql


select count(*) "starting" from apidb.TextSearchableComment;

truncate table apidb.TextSearchableComment;

select count(*) "after truncate" from apidb.TextSearchableComment;

insert into apidb.TextSearchableComment
            (comment_id, source_id, project_id, organism, content)
select c.comment_id, ci.stable_id, c.project_name, c.organism,
       c.headline || '|' || c.content || '|' ||  u.first_name || ' '
       || u.last_name || '(' || u.organization || ')' || apidb.author_list(c.comment_id)
from usercomments.comments c, usercomments.users u,
     (select comment_id, stable_id from usercomments.comments
       union
       select comment_id, stable_id from usercomments.commentStableId) ci
where c.comment_target_id = 'gene'
  and c.comment_id = ci.comment_id
  and c.user_id = u.user_id(+);

select count(*) "after insert" from apidb.TextSearchableComment;

exit
