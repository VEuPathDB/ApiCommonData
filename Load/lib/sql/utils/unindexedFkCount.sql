-- for each column with a foreign-key constraint but no index (which is a
-- potential performance problem), generates an SQL statement to count rows

select 'select count(*) ' || owner || '_' || table_name || ' from ' || owner || '.' || table_name
       || ' where ' || column_name || ' is not null;' as q
from (  select owner, table_name, column_name
        from all_tab_columns
        where column_name -- shares a name with a PK
              in (select column_name
                  from all_cons_columns
                  where (owner, constraint_name)
                        in (select owner, constraint_name
                            from all_constraints
                            where constraint_type = 'P')
                    -- and column_name like '%ID'
                    and column_name not in ('SOURCE_ID', 'NAME')
                    and owner -- only GUS-table PK names
                        in (select upper(name) from core.DatabaseInfo)
                    and owner != 'APIDBTUNING' -- no tuning-table PK names
                 )
          and owner -- only GUS tables
              in (select upper(name) from core.DatabaseInfo)
          and owner not in ('APIDBTUNING', 'APIDBUSERDATASETS')
          and owner not like '%VER' -- no GUS version tables
          and (owner, table_name)
              in (select owner, table_name from all_tables) -- not views
      minus
        -- columns with foreign-key or primary-key constraints
        select owner, table_name, column_name
      from all_cons_columns
      where (owner, constraint_name)
            in (select owner, constraint_name
                from all_constraints
                where constraint_type in ('P', 'R'))
        and owner
            in (select upper(name) from core.DatabaseInfo)
  );
