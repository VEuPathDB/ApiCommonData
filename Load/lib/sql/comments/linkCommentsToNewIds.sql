-- Find gene ID / comment ID pairs such that the gene ID is a current gene ID
-- and it is linked by the GeneId table to an alternate ID, and the alternate
-- ID / comment ID pair ARE linked in the comment database (either by
-- comments2.comments or by comments2.CommentStableId), but the current gene ID
-- is NOT linked to the comment ID. And insert those pairs into
-- comments2.CommentStableId, so they are linked. This allows comments to come
-- along when gene IDs change.

-- This script must be run in each component instance, not the comments
-- instance, since that's where the old-to-new-ID mappings are.

-- usage:
--          sqlplus <username>/<password>@<instance> <dblink>
-- example:
--          sqlplus fred/pwd123@plas-inc apidb.login_comment


-- don't print before-and-after copies of lines with the ampersand-one macro
set verify off

prompt inserting records to link changed gene IDs to existing comments
prompt

prompt checking CommentStableId primary key before insert
select comments2.CommentStableId_pkseq.nextval@&1 "comment_stable_id BEFORE insert"
from dual;

insert into comments2.CommentStableId@&1
            (stable_id, comment_id, comment_stable_id) -- shouldn't that be "comment_stable_id_id"?
select gene, comment_id, comments2.CommentStableId_pkseq.nextval@&1
from (  select gi.gene, comment_id
        from ApidbTuning.GeneId gi,
             (  select stable_id, comment_id
                from comments2.comments@&1
                where project_name in (select project_id from ApidbTuning.GeneAttributes)
              union
                select csi.stable_id, csi.comment_id
                from comments2.comments@&1 c, comments2.commentStableId@&1 csi
                where csi.comment_id = c.comment_id
                  and c.project_name in (select project_id from ApidbTuning.GeneAttributes)) apicomm_pairs
        where apicomm_pairs.stable_id = gi.id
      minus
        (  select stable_id, comment_id from comments2.comments@&1
         union
           select stable_id, comment_id from comments2.commentStableId@&1));

prompt to examine linked comments, run this query in the apicomm instance, substituting the comment_stable_id value from the BEFORE query above:
select 'select csi.stable_id as "new gene ID", headline, comment_date, content' || chr(10) ||
       'from comments2.comments c, comments2.commentStableId csi' || chr(10) ||
       'where csi.comment_stable_id between <BEFORE comment_stable_id> and ' || comments2.CommentStableId_pkseq.nextval@&1 || chr(10) ||
       '  and csi.comment_id = c.comment_id' || chr(10) ||
       'order by c.comment_id;' as "test query"
from dual;
