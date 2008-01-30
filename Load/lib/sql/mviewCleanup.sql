-------------------------------------------------------------------------------
-- mviewCleanup.sql
--
-- partially redundant with createApidbTuning.sql
-- see that script for an explaination of our system of materialized views
-- and synonyms

set time on timing on pagesize 50000 linesize 100

prompt Run these statements to test synonyms
select 'select count(*) as ' || synonym_name || ' from ' || owner || '.' || synonym_name || ';'
       as "synonym tests"
from all_synonyms
where owner='APIDB';

prompt These mviews appear superfluous (their names end in four digits but no synonym points at them).
prompt Consider dropping them if all synonyms are OK.

SELECT 'drop materialized view ' || owner || '.' || mview_name || ';' AS drops
FROM all_mviews
WHERE mview_name IN (SELECT mview_name
                     FROM all_mviews
                    MINUS
                     SELECT table_name
                     FROM all_synonyms)
  AND REGEXP_REPLACE(mview_name, '[0-9][0-9][0-9][0-9]', 'fournumbers')
      LIKE '%fournumbers';

exit
