create or replace function apidb.reverse_complement (seq varchar2)
return varchar2
is
    rslt varchar2(4000);
    idx    number;
begin
    rslt := '';
    for idx IN 1 .. length(seq)
    loop
        case upper(substr(seq, idx, 1))
            when 'A' then rslt := 'T' || rslt;
            when 'C' then rslt := 'G' || rslt;
            when 'G' then rslt := 'C' || rslt;
            when 'T' then rslt := 'A' || rslt;
        end case;
    end loop;
    return rslt;
end reverse_complement;
/

show errors;

GRANT execute ON apidb.reverse_complement TO gus_r;
GRANT execute ON apidb.reverse_complement TO gus_w;

exit;
