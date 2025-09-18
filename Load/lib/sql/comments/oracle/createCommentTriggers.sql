grant select on usercomments.CommentReference to apidb;

alter table usercomments.comment_users
add (constraint pk_users primary key (user_id) validate);

alter table usercomments.Comments
add (constraint comment_pk primary key (comment_id) validate);

alter table usercomments.Comments
   add (constraint user_fk foreign key (user_id)
        references usercomments.comment_users validate);


create or replace function apidb.author_list (p_comment_id number)
return varchar2
is
    authors varchar2(4000);
begin
    select apidb.tab_to_string(set(CAST(COLLECT(source_id) AS apidb.varchartab)), ', ')
    into authors
    from (select source_id
          from usercomments.CommentReference
          where database_name = 'author'
            and comment_id = p_comment_id
          order by source_id);

    return authors;
end;
/

show errors;

grant execute on apidb.author_list to public;

create or replace trigger usercomments.comments_insert
  after insert on usercomments.Comments
  for each row
declare
  userinfo varchar2(1000);
begin

  if :new.is_visible = 1 then
    begin
      select first_name || ' ' || last_name || '(' || organization || ')'
      into userinfo
      from usercomments.comment_users
      where user_id = :new.user_id;
    exception
      when NO_DATA_FOUND then
        userinfo := ' ()'; -- literals from userinfo string
    end;

    insert into apidb.TextSearchableComment (comment_id, comment_target_type, source_id, project_id, organism, content)
    values (:new.comment_id, :new.comment_target_id, :new.stable_id, :new.project_name, :new.organism,
            :new.headline || '|' || :new.content || '|' || userinfo || apidb.author_list(:new.comment_id));
  end if;
end;
/

create or replace trigger usercomments.comments_delete
  after delete on usercomments.Comments
  for each row
begin
  delete from apidb.TextSearchableComment
  where comment_id = :old.comment_id;
end;
/

create or replace trigger usercomments.comments_update
  after update on usercomments.Comments
  for each row
declare
  userinfo varchar2(1000);
  authorinfo varchar2(4000);
begin
  delete from apidb.TextSearchableComment
  where comment_id = :old.comment_id;

  if :new.is_visible = 1 then
    begin
      select first_name || ' ' || last_name || '(' || organization || ')'
      into userinfo
      from usercomments.comment_users
      where user_id = :new.user_id;
    exception
      when NO_DATA_FOUND then
        userinfo := ' ()'; -- literals from userinfo string
    end;

    select apidb.author_list(:new.comment_id)
    into authorinfo
    from dual;

    insert into apidb.TextSearchableComment (comment_id, comment_target_type, source_id, project_id, organism, content)
    values (:new.comment_id, :new.comment_target_id, :new.stable_id, :new.project_name, :new.organism,
            :new.headline || '|' || :new.content || '|' || userinfo || apidb.author_list(:new.comment_id));

    insert into apidb.TextSearchableComment (comment_id, comment_target_type, source_id, project_id, organism, content)
    select :new.comment_id, :new.comment_target_id, stable_id, :new.project_name, :new.organism,
            :new.headline || '|' || :new.content || '|' || userinfo || apidb.author_list(:new.comment_id)
    from usercomments.CommentStableId
    where comment_id = :new.comment_id
      and stable_id != :new.stable_id;
  end if;
end;
/

create or replace trigger usercomments.csi_insert
  after insert on usercomments.CommentStableId
  for each row
declare
  userinfo varchar2(1000);
  project varchar2(80);
begin
    select project_name into project from usercomments.comments where comment_id = :new.comment_id;

   begin
      select first_name || ' ' || last_name || '(' || organization || ')'
      into userinfo
      from usercomments.comment_users
      where user_id = (select user_id from usercomments.Comments where comment_id = :new.comment_id);
    exception
      when NO_DATA_FOUND then
        userinfo := ' ()'; -- literals from userinfo string
    end;

  insert into apidb.TextSearchableComment (comment_id, comment_target_type, source_id, project_id, organism, content)
  select comment_id, comment_target_id, :new.stable_id, project_name, organism,
          headline || '|' || content || '|' || userinfo || apidb.author_list(comment_id)
  from usercomments.Comments
  where comment_id = :new.comment_id
    and is_visible = 1
    and stable_id != :new.stable_id; -- don't duplicate comment-target pairs
end;
/

show errors

create or replace trigger usercomments.csi_delete
  after delete on usercomments.CommentStableId
  for each row
begin
  delete from apidb.TextSearchableComment
  where comment_id = :old.comment_id
    and source_id = :old.stable_id
    -- last condition ensures that the mapping being deleted
    -- is not duplicated in the comment table itself
    and source_id != (select stable_id
                      from usercomments.Comments
                      where comment_id = :old.comment_id);
end;
/

create or replace trigger usercomments.csi_update
  after update on usercomments.CommentStableId
  for each row
declare
  userinfo varchar2(1000);
  project varchar2(80);
begin

  delete from apidb.TextSearchableComment
  where comment_id = :old.comment_id
    and source_id = :old.stable_id
    and (:old.comment_id, :old.stable_id)
        not in (select comment_id, stable_id from usercomments.Comments);

  select project_name into project from usercomments.comments where comment_id = :new.comment_id;

  begin
    select first_name || ' ' || last_name || '(' || organization || ')'
    into userinfo
    from usercomments.comment_users
    where user_id = (select user_id from usercomments.Comments where comment_id = :new.comment_id);
  exception
    when NO_DATA_FOUND then
      userinfo := ' ()'; -- literals from userinfo string
  end;

  insert into apidb.TextSearchableComment (comment_id, comment_target_type, source_id, project_id, organism, content)
  select comment_id, comment_target_id, :new.stable_id, project_name, organism,
          headline || '|' || content || '|' || userinfo || apidb.author_list(comment_id)
  from usercomments.Comments
  where comment_id = :new.comment_id
        and is_visible = 1;

end;
/

-- Changes to CommentReference can trigger only updates to TextSearchableComment.
-- But the recording of affected comment IDs must be separated from the updating
-- of those comments' content strings, to avoid the dread
-- "ORA-04091: table CommentReference is mutating, trigger/function may not see it".
-- This is an issue for CommentReference (unlike Comments and CommentStableId) because
-- the affected TextSearchableComment records must aggregate all author records
-- in CommentReference.
--
-- hence, three triggers, plus a package to let them share info

create or replace package usercomments.cmntRef_trggr_pkg
as
    type commentIdList is table of number index by binary_integer;
         stale    commentIdList;
         empty    commentIdList;
     end;
/

-- a statement-level trigger runs before a row-level trigger when both are fired
-- by a single SQL statement
-- http://docs.oracle.com/cd/B19306_01/server.102/b14220/triggers.htm#sthref3278

-- once per statement, initialize the list of comments IDs affected by the triggering change to CommentReference.
create or replace trigger usercomments.cmntRef_setup
before insert or update or delete on usercomments.CommentReference
begin
    cmntRef_trggr_pkg.stale := cmntRef_trggr_pkg.empty;
end;
/

-- once per row, note the ID of the comment that had an author inserted
create or replace trigger usercomments.cmntRef_markInsertedId
before insert on usercomments.CommentReference
for each row
declare
    i    number default cmntRef_trggr_pkg.stale.count+1;
begin
    cmntRef_trggr_pkg.stale(i) := :new.comment_id;
end;
/

-- once per row, note the ID of the comment that had an author deleted
create or replace trigger usercomments.cmntRef_markDeletedId
before delete on usercomments.CommentReference
for each row
declare
    i    number default cmntRef_trggr_pkg.stale.count+1;
begin
    cmntRef_trggr_pkg.stale(i) := :old.comment_id;
end;
/

-- once per row, note the ID of the comment that had an author updated
create or replace trigger usercomments.cmntRef_markUpdatedId
before update on usercomments.CommentReference
for each row
declare
    i    number default cmntRef_trggr_pkg.stale.count+1;
begin
    cmntRef_trggr_pkg.stale(i) := :old.comment_id;
    cmntRef_trggr_pkg.stale(i+1) := :new.comment_id;
end;
/

-- after the statement, update the content of affected TextSearchableComment records
create or replace trigger usercomments.cmntRef_updateTsc
   after insert or update or delete on usercomments.CommentReference
declare
  userinfo varchar2(1000);
  project varchar2(80);
begin
    for i in 1 .. cmntRef_trggr_pkg.stale.count loop

      select project_name into project from usercomments.comments where comment_id = cmntRef_trggr_pkg.stale(i);

      begin
        select first_name || ' ' || last_name || '(' || organization || ')'
        into userinfo
        from usercomments.comment_users
        where user_id = (select user_id from usercomments.Comments where comment_id = cmntRef_trggr_pkg.stale(i));
      exception
        when NO_DATA_FOUND then
          userinfo := ' ()'; -- literals from userinfo string
      end;

      update apidb.TextSearchableComment
      set content = (select headline || '|' || content || '|' || userinfo || apidb.author_list(comment_id)
                     from usercomments.Comments
                     where comment_id = cmntRef_trggr_pkg.stale(i))
      where comment_id = cmntRef_trggr_pkg.stale(i);
    end loop;
end;
/

create or replace trigger usercomments.users_update
before update on usercomments.comment_users
for each row
declare
  userinfo varchar2(1000);
begin
    userinfo := :new.first_name || ' ' || :new.last_name || '(' || :new.organization || ')';

    update apidb.TextSearchableComment
    set content = (select headline || '|' || content || '|' || userinfo || apidb.author_list(comment_id)
                   from usercomments.Comments
                   where comment_id = TextSearchableComment.comment_id)
    where comment_id in (select comment_id from usercomments.comments where user_id = :new.user_id);
end;
/
