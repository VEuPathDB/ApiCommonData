create or replace function apidb.searchable_comment_text (p_comment_id number)
return clob
is
    smooshed clob;
begin
    select c.headline || '|' || c.content || '|' || 
           u.first_name || ' ' || u.last_name || '(' || u.organization || ')' into smooshed
    from comments2.comments c, userlogins3.users u
    where c.email = u.email(+)
      and c.comment_id = p_comment_id;
    return smooshed;
end;
/

grant execute on apidb.searchable_comment_text to public;

drop table apidb.TextSearchableComment;
create table apidb.TextSearchableComment as
select comment_id, stable_id as source_id, project_name as project_id, organism,
       apidb.searchable_comment_text(comment_id) as content
from comments2.comments;

grant select,insert,update,delete on apidb.TextSearchableComment to public;

create index apidb.comments_text_ix
on apidb.TextSearchableComment(content)
indextype is ctxsys.context
parameters('DATASTORE CTXSYS.DEFAULT_DATASTORE SYNC (ON COMMIT)');

create or replace procedure apidb.move_comments
is
begin
  insert into apidb.TextSearchableComment (comment_id, source_id, project_id, organism, content)
  select comment_id, stable_id, project_name, organism,
          apidb.searchable_comment_text(comment_id)
  from comments2.comments
  where comment_id not in (select comment_id from apidb.TextSearchableComment);
end;
/

grant execute on apidb.move_comments to public;

create or replace trigger comments2.comments_insert
after insert on comments2.comments
begin
  apidb.move_comments;
end;
/

-- this update trigger won't do the right thing if the comment_id itself is updated
create or replace trigger comments2.comments_update
after update on comments2.comments
for each row
begin
  update apidb.TextSearchableComment
  set content = apidb.searchable_comment_text(:new.comment_id)
  where comment_id = :new.comment_id;
end;
/

create or replace trigger comments2.comments_delete
after delete on comments2.comments
begin
  delete from apidb.TextSearchableComment
  where comment_id not in (select comment_id from comments2.comments);
end;
/

BEGIN
  dbms_ddl.set_trigger_firing_property('comments2', 'comments_insert', FALSE);
  dbms_ddl.set_trigger_firing_property('comments2', 'comments_update', FALSE);
  dbms_ddl.set_trigger_firing_property('comments2', 'comments_delete', FALSE);
END;
/

BEGIN
DBMS_SCHEDULER.DROP_JOB(job_name => 'apidb.comment_mover');
END;
/

BEGIN
DBMS_SCHEDULER.CREATE_JOB(
job_name => 'apidb.comment_mover',
job_type => 'PLSQL_BLOCK',
job_action => 'begin apidb.move_comments(); end',
start_date => sysdate+ 1/(24*60*12), -- five seconds
repeat_interval => 'FREQ=DAILY'
);
END;
/

BEGIN
DBMS_SCHEDULER.DROP_JOB(
  job_name => 'apidb.optimize_index'
);
END;
/

BEGIN
DBMS_SCHEDULER.CREATE_JOB(
job_name => 'optimize_index',
job_type => 'PLSQL_BLOCK',
job_action => 'begin CTX_DDL.OPTIMIZE_INDEX(''comments_text_ix'',''FULL''); apidb.move_comments; end',
start_date => sysdate+ 1/(24*60*12), -- five seconds
repeat_interval => 'FREQ=DAILY'
);

DBMS_SCHEDULER.ENABLE('optimize_index');
END;
/

