
-- update (so-called) stable_id field for renamed P.f. genes
update comments2.comments set stable_id = 'CYTB' where stable_id = 'coxI';
update comments2.comments set stable_id = 'MAL7P1.231' where stable_id = 'MAL7P1.321';
update comments2.comments set stable_id = 'PFC0355c' where stable_id = 'PFC0358c';

-- generate (most of) a query for comments whose stable_id is not a valid gene
-- must drop last "union" and append "minus select source_id from apidb.GeneAttributes"
spool commentedGenes.sql
select distinct 'select ''' || stable_id || ''' from dual union'
from comments2.comments
where project_name = 'PlasmoDB' and comment_target_id = 'gene';
spool off

