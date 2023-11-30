-------------------------------------------------------------------------------
create or replace function apidb.project_id (organism varchar2)
return varchar2
is
   project varchar2(80);
   org varchar2(200);

begin

   begin

      -- find a TAXON in ProjectTaxon that matches the first N characters of the
      -- organism name passed as an argument, where N is the length of that
      -- ProjectTaxon.TAXON. (That is, find a match for the whole length of the
      -- name in ProjectTaxon). If multiple records in ProjectTaxon match for
      -- the full length, use the longest one.

      org := replace(organism, '''', '');
      execute immediate
         'select project_id ' ||
         'from (select project_id, ' ||
         '             row_number() over (order by length(pt.taxon) desc) as ranking ' ||
         '      from ApidbTuning.ProjectTaxon pt ' ||
         '      where pt.taxon = substr(lower(''' || org || '''), 1, length(pt.taxon)) ' ||
         '     ) ' ||
         'where ranking = 1 '
      into project;
      exception
         when NO_DATA_FOUND then
              project := 'PiroplasmaDB';
--            raise_application_error(-20101,
--                                    'project_id("'|| organism || '"): unknown project assignment' );
   end;

   return project;

end project_id;
/

show errors;

GRANT execute ON apidb.project_id TO public;
-------------------------------------------------------------------------------
create or replace function apidb.wrap (seq clob)
return clob
is
    rslt      clob;
    maxchunk  number;
    linesize  number;
    idx       number;
    delimiter char;

begin
    linesize := 60;
    delimiter := chr(10);


    if seq is null or length(seq) <= linesize
    then
      rslt := seq;

    else 
        maxchunk := ceil(length(seq) / linesize) - 1;

        for idx in 0 .. maxchunk
        loop
            if idx > 0
            then
                rslt := rslt || delimiter;
            end if;

            rslt := rslt || dbms_lob.substr(seq, linesize, idx * linesize + 1);
        end loop;
    end if;

    return rslt;
end wrap;
/

show errors;

GRANT execute ON apidb.wrap TO gus_r;
GRANT execute ON apidb.wrap TO gus_w;

-------------------------------------------------------------------------------

CREATE OR REPLACE TYPE apidb.varchartab AS TABLE OF VARCHAR2(4000);
/

GRANT execute ON apidb.varchartab TO PUBLIC;

CREATE OR REPLACE FUNCTION
apidb.tab_to_string (p_varchar2_tab  IN  apidb.varchartab,
                     p_delimiter     IN  VARCHAR2 DEFAULT ',')
RETURN VARCHAR2 IS
l_string     VARCHAR2(32767);
BEGIN

  IF p_varchar2_tab.FIRST IS NULL THEN
    RETURN null;
  END IF;

  FOR i IN p_varchar2_tab.FIRST .. p_varchar2_tab.LAST LOOP
    IF i != p_varchar2_tab.FIRST AND length(l_string) < 4000 THEN
      l_string := l_string || p_delimiter;
    END IF;

    IF length(l_string) >= 3997 THEN
      l_string := SUBSTR(l_string, 1, 3997) ||  '...' ;
    ELSIF (length(l_string) + length(p_varchar2_tab(i))) > 4000 THEN
      l_string := l_string || SUBSTR(p_varchar2_tab(i), 1, 3997 - length(l_string)) || '...' ;
    ELSE
      l_string := l_string || p_varchar2_tab(i);
    END IF;
  END LOOP;

  RETURN l_string;

END tab_to_string;
/

show errors;

GRANT execute ON apidb.tab_to_string TO PUBLIC;

-------------------------------------------------------------------------------
exit
