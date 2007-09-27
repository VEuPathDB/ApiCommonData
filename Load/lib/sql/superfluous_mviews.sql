
/*
   superfluous_mviews.sql

   Finds materialized views whose names end in four digits and which have no
   synonyms pointing to them.  These are probably obsolete.

   Example: The synonym GeneAttributes points to the mview GeneAttributes1111.
   We want to change its schema, so we create GeneAttributes2468 and point the
   synonym at it.  GeneAttributes1111 is now obsolete, and can be dropped.

   For convenience, the output is in the form of "drop materialized view"
   statements.
*/


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
