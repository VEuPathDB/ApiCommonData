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
