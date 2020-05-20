-- This script drops "orphan" tuning tables.
--
-- Tuning tables always consist of a table with a name like "GeneAttributes1234",
-- together with a synonym, like "GeneAttributes", pointing at it. That's what
-- makes it possible to make a new GeneAttributes while the web site is using the
-- current GeneAttributes.
--
-- If a tuning table build fails, the table can be left behind. This script drops
-- these orphaned tuning tables. They can be recognized because their names end
-- in four digits but no synonym points at them.
--
-- this script must be run as the apidbTuning user

set pagesize 50000 linesize 100

spool o.sql

SELECT 'drop table ' || owner || '.' || table_name || ';'
       AS "-- orphaned tuning tables"
FROM all_tables
WHERE table_name IN (SELECT table_name
                     FROM all_tables
                    MINUS
                     SELECT table_name
                     FROM all_synonyms
                    MINUS
                     SELECT mview_name
                     FROM all_mviews)
  AND REGEXP_REPLACE(table_name, '[0-9][0-9][0-9][0-9]$', 'fournumbers')
      LIKE '%fournumbers'
  AND table_name NOT LIKE 'QUERY_RESULT_%'
  AND owner != 'SYS'
  AND owner != 'APEX_030200'
  AND owner != 'CTXSYS'
  AND owner != 'EXFSYS'
  AND owner != 'SYSMAN'
  AND owner != 'WMSYS'
ORDER BY owner, table_name;

spool off

@o

exit
