-------------------------------------------------------------------------------
create or replace function apidb.project_id (organism varchar2)
return varchar2
is
   project varchar2(80);

begin

   begin
      execute immediate
         'select distinct project_id ' ||
         'from ApidbTuning.ProjectTaxon pt ' ||
         'where pt.taxon = substr(lower(''' || organism || '''), 1, length(pt.taxon)) '
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
exit
