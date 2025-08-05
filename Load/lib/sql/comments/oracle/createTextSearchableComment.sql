drop table apidb.TextSearchableComment;

create table apidb.TextSearchableComment (
  comment_id number(10) not null,
  source_id  varchar2(100),
  project_id varchar2(40),
  organism   varchar2(100),
  content    clob
);

grant select,insert,update,delete on apidb.TextSearchableComment to public;

create index apidb.comments_text_ix
on apidb.TextSearchableComment(content)
indextype is ctxsys.context
parameters('DATASTORE CTXSYS.DEFAULT_DATASTORE SYNC (ON COMMIT)');

create index apidb.commentid_ix
on apidb.TextSearchableComment(comment_id);
