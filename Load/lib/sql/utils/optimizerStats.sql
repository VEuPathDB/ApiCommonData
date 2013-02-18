-- For a table that has a MODIFICATION_DATE column (as most GUS tables do),
-- this script compares those values with all_tables.LAST_ANALYZED to determine
-- how much of the table has changed since optimizer statistics were last
-- computed for it.
--
-- usage:   sqlplus <user>/<password>@<instance> @optimzerStats <table>
-- example: sqlplus apidb/<password>@tryp420s @optimzerStats dots.NaFeatureImp

set verify off

column min_mod_date format a12
column max_mod_date format a12

prompt table stats
select count(*), to_char(min(modification_date), 'dd-mon-yyyy') as min_mod_date,
       to_char(max(modification_date), 'dd-mon-yyyy') as max_mod_date
from &1;

prompt system info
select  to_char(last_analyzed, 'dd-mon-yyyy hh24:mi:ss') as last_analyzed
from all_tables
where upper(owner || '.' || table_name) = upper('&1');

prompt comparison
with alltabs as (select last_analyzed
                 from all_tables
                 where upper(owner || '.' || table_name) = upper('&1')),
     recs as (select case when modification_date < alltabs.last_analyzed
                           then 1
                         else 0
                    end as analyzed
              from alltabs, &1)
select count(*) as total_records, sum(analyzed) as analyzed_records,
       count(*) - sum(analyzed) as unanalyzed_records,
       case when count(*) is null then null
            else (sum(analyzed) / count(*)) * 100
       end as percent_analyzed
from recs;

exit

