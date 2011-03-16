-- Find gene ID / comment ID pairs such that the gene ID is a current gene ID
-- and it is linked by the GeneId table to an alternate ID, and the alternate
-- ID / comment ID pair ARE linked in the comment database (either by
-- comments2.comments or by comments2.CommentStableId), but the current gene ID
-- is NOT linked to the comment ID. And insert those pairs into
-- comments2.CommentStableId, so they are linked. This allows comments to come
-- along when gene IDs change.

insert into comments2.CommentStableId@apidb.login_comment
            (stable_id, comment_id, comment_stable_id) -- shouldn't that be "comment_stable_id_id"?
select gene, comment_id, comments2.CommentStableId_pkseq.nextval@apidb.login_comment
from (  select gi.gene, comment_id
        from apidb.GeneId gi,
             (  select stable_id, comment_id
                from comments2.comments@apidb.login_comment
                where project_name in (select project_id from apidb.GeneAttributes)
              union
                select csi.stable_id, csi.comment_id
                from comments2.comments@apidb.login_comment c, comments2.commentStableId@apidb.login_comment csi
                where csi.comment_id = c.comment_id
                  and c.project_name in (select project_id from apidb.GeneAttributes)) apicomm_pairs
        where apicomm_pairs.stable_id = gi.id
      minus
        (  select stable_id, comment_id from comments2.comments@apidb.login_comment
         union
           select stable_id, comment_id from comments2.commentStableId@apidb.login_comment));
