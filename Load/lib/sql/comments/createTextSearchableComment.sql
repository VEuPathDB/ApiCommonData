drop table apidb.TextSearchableComment;

create table apidb.TextSearchableComment nologging as
select c.comment_id, ci.stable_id as source_id, c.project_name as project_id, c.organism,
       c.headline || '|' || c.content || '|' ||  u.first_name || ' '
       || u.last_name || '(' || u.organization || ')' || apidb.author_list(c.comment_id) as content
from comments2.comments c, userlogins3.users u,
     (select comment_id, stable_id from comments2.comments
       union
       select comment_id, stable_id from comments2.commentStableId) ci
where c.comment_target_id = 'gene'
  and c.comment_id = ci.comment_id
  and c.user_id = u.user_id(+);

grant select,insert,update,delete on apidb.TextSearchableComment to public;

create index apidb.comments_text_ix
on apidb.TextSearchableComment(content)
indextype is ctxsys.context
parameters('DATASTORE CTXSYS.DEFAULT_DATASTORE SYNC (ON COMMIT)');
