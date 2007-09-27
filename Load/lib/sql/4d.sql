/*
   4d.sql -- Show digits embedded in materialized-view names
             (See createBfmv.sql for why we care).
             Note that an mview named 'flank3prime2222' would generate the
             output value '32222'.
*/

select distinct regexp_replace(mview_name, '[^0-9]*', '')
       as "digits embedded in mview names"
from all_mviews
where regexp_replace(mview_name, '[0-9][0-9][0-9][0-9]', 'fournumbers')
      like '%fournumbers'
order by regexp_replace(mview_name, '[^0-9]*', '');

exit;
