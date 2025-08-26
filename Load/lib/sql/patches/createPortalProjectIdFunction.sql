-------------------------------------------------------------------------------
-- To be used ONLY ON portal database instances 
--   AFTER SequenceAttributes tuningTable exists on it
-------------------------------------------------------------------------------
create or replace function apidb.project_id (orgParam varchar2)
return varchar2
is
   project varchar2(80);
begin
      select distinct sa.project_id 
      into project
      from webready.GenomicSeqAttributes sa
      where SUBSTR(sa.organism,1,(INSTR(sa.organism,' ',1,1)-1)) = SUBSTR(orgParam,1,(INSTR(orgParam||' ',' ',1,1)-1));
    return project;

end project_id;
/
show errors;

GRANT execute ON apidb.project_id TO public;

-------------------------------------------------------------------------------
