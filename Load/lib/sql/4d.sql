set pagesize 50000

/*
   4d.sql -- Show digits embedded in table names (including materialized views)
             (See updateApidbTuning.sql for why we care).
             Note that a table named 'flank3prime2222' would generate the
             output value '32222'.
*/

select distinct regexp_replace(table_name, '[^0-9]*', '')
       as "digits embedded in table names"
from all_tables
where regexp_replace(table_name, '[0-9][0-9][0-9][0-9]', 'fournumbers')
      like '%fournumbers'
  AND owner != 'SYS'
  AND table_name not like 'QUERY_RESULT_%'
order by regexp_replace(table_name, '[^0-9]*', '');

exit;
