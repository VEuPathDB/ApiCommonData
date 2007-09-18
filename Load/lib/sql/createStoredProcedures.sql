create or replace function apidb.reverse_complement_clob (seq clob)
return clob
is
    rslt clob;
    idx    number;
begin
    rslt := '';
    if seq is not null
    then
        for idx IN 1 .. length(seq)
        loop
            case upper(substr(seq, idx, 1))
                when 'A' then rslt := 'T' || rslt;
                when 'C' then rslt := 'G' || rslt;
                when 'G' then rslt := 'C' || rslt;
                when 'T' then rslt := 'A' || rslt;
                else rslt := substr(seq, idx, 1) || rslt;
            end case;
        end loop;
    end if;
    return rslt;
end reverse_complement_clob;
/

show errors;

GRANT execute ON apidb.reverse_complement_clob TO gus_r;
GRANT execute ON apidb.reverse_complement_clob TO gus_w;

-------------------------------------------------------------------------------
create or replace function apidb.reverse_complement (seq varchar2)
return varchar2
is
    rslt varchar2(4000);
    idx    number;
begin
    rslt := '';
    if seq is not null
    then
        for idx IN 1 .. length(seq)
        loop
            case upper(substr(seq, idx, 1))
                when 'A' then rslt := 'T' || rslt;
                when 'C' then rslt := 'G' || rslt;
                when 'G' then rslt := 'C' || rslt;
                when 'T' then rslt := 'A' || rslt;
                else rslt := substr(seq, idx, 1) || rslt;
            end case;
        end loop;
    end if;
    return rslt;
end reverse_complement;
/

show errors;

GRANT execute ON apidb.reverse_complement TO gus_r;
GRANT execute ON apidb.reverse_complement TO gus_w;

-------------------------------------------------------------------------------

CREATE OR REPLACE TYPE apidb.varchartab AS TABLE OF VARCHAR2(4000);
/

GRANT execute ON apidb.varchartab TO gus_r;
GRANT execute ON apidb.varchartab TO gus_w;

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
    IF i != p_varchar2_tab.FIRST THEN
      l_string := l_string || p_delimiter;
    END IF;
    l_string := l_string || p_varchar2_tab(i);
  END LOOP;
  IF length(l_string) > 4000 THEN
    l_string := substr(l_string, 1, 3997) || '...';
  END IF;
  RETURN l_string;
END tab_to_string;
/

show errors;

GRANT execute ON apidb.tab_to_string TO gus_r;
GRANT execute ON apidb.tab_to_string TO gus_w;

exit;
