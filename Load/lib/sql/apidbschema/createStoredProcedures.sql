-------------------------------------------------------------------------------
create or replace function apidb.reverse_complement_clob (seq clob)
return clob
is
    rslt clob;
    idx  number;
begin
    rslt := '';
    for idx in reverse 1 .. length(seq) loop
        rslt := rslt
                || translate(substr(seq, idx, 1), 'atugcyrkmbdhvATUGCYRKMBDHV', 'taacgrymkvhdbTAACGRYMKVHDB');
    end loop;
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
    idx  number;
begin
    rslt := '';
    for idx in reverse 1 .. length(seq) loop
        rslt := rslt
                || translate(substr(seq, idx, 1), 'atugcyrkmbdhvATUGCYRKMBDHV', 'taacgrymkvhdbTAACGRYMKVHDB');
    end loop;
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

GRANT execute ON apidb.tab_to_string TO gus_r;
GRANT execute ON apidb.tab_to_string TO gus_w;

-------------------------------------------------------------------------------
create or replace procedure apidb.analyze (schema_name IN varchar2, table_name IN varchar2)
authid current_user -- run with the privileges of the database user who calls it, not the owner (which is apidb)
is
begin
    -- table stats
    dbms_output.put_line( '  Updating stats for table ' || schema_name || '.' || table_name );
    dbms_stats.gather_table_stats(ownname => schema_name, tabname => table_name, estimate_percent => 100, degree => 2);

    -- index stats
    for i in (select distinct owner as index_owner, index_name
              from all_indexes
              where table_owner = schema_name
                and table_name = table_name
                and last_analyzed is null
                and index_type != 'DOMAIN')
    loop
        dbms_output.put_line( '    Updating stats for index ' || i.index_owner || '.' || i.index_name);
        dbms_stats.gather_index_stats(ownname => i.index_owner, indname => i.index_name, estimate_percent => 100, degree => 2);
    end loop;
end;
/

show errors
GRANT execute ON apidb.analyze TO gus_r;
GRANT execute ON apidb.analyze TO gus_w;

-------------------------------------------------------------------------------
/* ========================================================================== *
 * char_clob_agg function
 * aggregate varchar2 rows into a clob; delimited by new line
 * ========================================================================== */
create or replace type apidb.char_clob_agg_type as object
(
  char_content varchar2(29990),
  clob_content clob,
  delimiter char(1),

  static function ODCIAggregateInitialize
    ( sctx in out NOCOPY  char_clob_agg_type )
    return number ,

  member function ODCIAggregateIterate
    ( self  in out NOCOPY char_clob_agg_type ,
      value in            varchar2
    ) return number ,

  member function ODCIAggregateTerminate
    ( self        in  char_clob_agg_type,
      returnvalue out NOCOPY clob,
      flags       in  number
    ) return number ,

  member function ODCIAggregateMerge
    ( self in out NOCOPY char_clob_agg_type,
      ctx2 in            char_clob_agg_type
    ) return number
);
/

create or replace type body apidb.char_clob_agg_type
is

  static function ODCIAggregateInitialize
  ( sctx in out NOCOPY char_clob_agg_type )
  return number
  is
  begin

    sctx := char_clob_agg_type(NULL, NULL, chr(10)) ;
    dbms_lob.createtemporary(sctx.clob_content, true);

    return ODCIConst.Success ;

  end;

  member function ODCIAggregateIterate
  ( self  in out NOCOPY char_clob_agg_type ,
    value in            varchar2
  ) return number
  is
    current_length NUMBER;
    input_length NUMBER;
  begin

    current_length := length(self.char_content);
    input_length := length(value);
    IF current_length + input_length > 29900 THEN
      IF dbms_lob.getlength(self.clob_content) > 0 THEN
        dbms_lob.writeappend(self.clob_content, 1, self.delimiter);
      END IF;
      dbms_lob.writeappend(self.clob_content, current_length, self.char_content);
      self.char_content := value;
    ELSIF input_length > 0 THEN
      IF current_length > 0 THEN
        self.char_content := self.char_content || self.delimiter;
      END IF;
      self.char_content := self.char_content || value;
    END IF;

    return ODCIConst.Success;

  end;

  member function ODCIAggregateTerminate
  ( self        in         char_clob_agg_type ,
    returnvalue out NOCOPY clob ,
    flags       in         number
  ) return number
  is
    char_length NUMBER;
  begin

    char_length := length(self.char_content);
    returnValue := self.clob_content;
    IF char_length > 0 THEN
      IF dbms_lob.getlength(returnValue) > 0 THEN
        dbms_lob.writeappend(returnValue, 1, self.delimiter);
      END IF;
      dbms_lob.writeappend(returnValue, char_length, self.char_content);
    END IF;

    return ODCIConst.Success;

  end;

  member function ODCIAggregateMerge
  ( self in out NOCOPY char_clob_agg_type ,
    ctx2 in            char_clob_agg_type
  ) return number
  is
    current_length NUMBER;
    input_length NUMBER;
  begin
   
    current_length := length(self.char_content);
    input_length := length(ctx2.char_content);
    IF dbms_lob.getlength(ctx2.clob_content) > 0 THEN
     IF dbms_lob.getlength(self.clob_content) > 0 THEN
        dbms_lob.writeappend(self.clob_content, 1, self.delimiter);
      END IF;
      IF current_length > 0 THEN
        dbms_lob.writeappend(self.clob_content, current_length + 1, self.char_content || self.delimiter);
      END IF;
      dbms_lob.append(self.clob_content, ctx2.clob_content);
      self.char_content := ctx2.char_content;
    ELSIF current_length + input_length > 29900 THEN
      IF dbms_lob.getlength(self.clob_content) > 0 THEN
        dbms_lob.writeappend(self.clob_content, 1, self.delimiter);
      END IF;
      dbms_lob.writeappend(self.clob_content, current_length, self.char_content);
      self.char_content := ctx2.char_content;
    ELSIF input_length > 0 THEN
      IF current_length > 0 THEN
          self.char_content := self.char_content || self.delimiter;
      END IF;
      self.char_content := self.char_content || ctx2.char_content;
    END IF;
    
    return ODCIConst.Success;

  end;

end;
/

create or replace function apidb.char_clob_agg
  ( input varchar2 )
  return clob
  deterministic
  parallel_enable
  aggregate using char_clob_agg_type
;
/

grant execute on apidb.char_clob_agg to public;

-------------------------------------------------------------------------------
/* ========================================================================== *
 * clob_clob_agg function
 * aggregate clob rows into a clob; delimited by new line
 * ========================================================================== */
create or replace type apidb.clob_clob_agg_type as object
(
  clob_content clob,
  delimiter char(1),

  static function ODCIAggregateInitialize
    ( sctx in out NOCOPY  clob_clob_agg_type )
    return number ,

  member function ODCIAggregateIterate
    ( self  in out NOCOPY clob_clob_agg_type ,
      value in            CLOB
    ) return number ,

  member function ODCIAggregateTerminate
    ( self        in  clob_clob_agg_type,
      returnvalue out NOCOPY CLOB,
      flags       in  number
    ) return number ,

  member function ODCIAggregateMerge
    ( self in out NOCOPY clob_clob_agg_type,
      ctx2 in            clob_clob_agg_type
    ) return number
);
/

create or replace type body apidb.clob_clob_agg_type
is

  static function ODCIAggregateInitialize
  ( sctx in out NOCOPY clob_clob_agg_type )
  return number
  is
  begin

    sctx := clob_clob_agg_type(NULL, chr(10)) ;
    dbms_lob.createtemporary(sctx.clob_content, true);

    return ODCIConst.Success ;

  end;

  member function ODCIAggregateIterate
  ( self  in out NOCOPY clob_clob_agg_type ,
    value in            CLOB
  ) return number
  is
    current_length NUMBER;
    input_length NUMBER;
  begin


    current_length := dbms_lob.getlength(self.clob_content);
    input_length   := dbms_lob.getlength(value);

    IF input_length > 0 THEN
      IF current_length > 0 THEN
        dbms_lob.writeappend(self.clob_content, 1, self.delimiter);
      END IF;
      dbms_lob.append(self.clob_content, value);
    END IF;

    return ODCIConst.Success;

  end;

  member function ODCIAggregateTerminate
  ( self        in         clob_clob_agg_type ,
    returnValue out NOCOPY CLOB ,
    flags       in         number
  ) return number
  is
    char_length NUMBER;
  begin

    returnValue := self.clob_content;

    return ODCIConst.Success;

  end;

  member function ODCIAggregateMerge
  ( self in out NOCOPY clob_clob_agg_type ,
    ctx2 in            clob_clob_agg_type
  ) return number
  is
    current_length NUMBER;
    input_length NUMBER;
  begin

/*   
    current_length := dbms_lob.getlength(self.clob_content);
    input_length   := dbms_lob.getlength(ctx2.clob_content);
    IF input_length > 0 THEN
      IF current_length > 0 THEN
        dbms_lob.writeappend(self.clob_content, 1, self.delimiter);
      END IF;
      dbms_lob.append(self.clob_content, ctx2.clob_content);
    END IF;
*/

    return ODCIConst.Success;

  end;

end;
/

create or replace function apidb.clob_clob_agg
  ( input clob )
  return clob
  deterministic
  --parallel_enable
  aggregate using clob_clob_agg_type
;
/

grant execute on apidb.clob_clob_agg to public;

-------------------------------------------------------------------------------

/**** remove all special characters from input string ****/

create or replace function apidb.alphanumeric_str(in_string varchar2)
return varchar2
is
    rslt varchar2(4000);
begin
    rslt := regexp_replace(in_string, '( *[[:punct:]])', '');
    return rslt;
end alphanumeric_str;
/

grant execute on apidb.alphanumeric_str to public;

-------------------------------------------------------------------------------
create or replace function apidb.project_id (organism varchar2)
return varchar2
is
   lowerOrg varchar2(50);
   project varchar2(80);
   isComponent number(1);
   queryFailed boolean;

begin

    queryFailed := false;

    -- figure out whether we're in a component or portal instance
    select count(*)
    into isComponent
    from all_tables
    where owner = 'SRES'
      and table_name = 'TAXON';

    lowerOrg := substr(lower(organism), 1, instr(organism||' ', ' ') - 1);

    if isComponent = 1 then
        -- component instance: check apidb.Organism
        begin

	    execute immediate
                'select distinct project_name ' ||
                'from (  select o.project_name ' ||
                '   from  sres.TaxonName tn, apidb.Organism o ' ||
                '   where SUBSTR(tn.name,1,(INSTR(tn.name, '' '',1,1)-1)) = ''' || lowerOrg || ''' ' ||
                '     and o.taxon_id = tn.taxon_id ' ||
                ' union ' ||
                '   select o.project_name ' ||
                '   from sres.TaxonName tn, sres.Taxon t, apidb.Organism o ' ||
                '   where tn.name = ''' || organism || ''' ' ||
                '     and tn.taxon_id = t.taxon_id ' ||
                '     and t.rank = ''family'' ' ||
                '     and '','' || o.family_ncbi_taxon_ids || '','' like ''%,'' || t.ncbi_tax_id || '',%'')'
            into project;

            exception

              when NO_DATA_FOUND then
              queryFailed := true;

        end;

    else
        -- portal instance: check ApidbTuning.ProjectMapping
        begin

	    execute immediate
                'select project_id from ApidbTuning.ProjectMapping where organism = ''' || lowerOrg || ''''
            into project;

            exception

              when NO_DATA_FOUND then
              queryFailed := true;

        end;

    end if;

    if queryFailed then
         -- use hardwired genus->project mappings
         case lowerOrg
            when 'apicomplexa' then project := 'EuPathDB';
            when 'diplomonadida' then project := 'GiardiaDB';
            when 'kinetoplastida' then project := 'TriTrypDB';
            when 'microsporidia' then project := 'MicrosporidiaDB';
            when 'trichomonadida' then project := 'TrichDB';
            when 'acanthamoeba' then project := 'AmoebaDB';
            when 'acanthamoebidae' then project := 'AmoebaDB';
            when 'anncaliia' then project := 'MicrosporidiaDB';
            when 'babesia' then project := 'PiroplasmaDB';
            when 'babesiidae' then project := 'PiroplasmaDB';
            when 'crithidia' then project := 'TriTrypDB';
            when 'cryptosporidiidae' then project := 'CryptoDB';
            when 'cryptosporidium' then project := 'CryptoDB';
            when 'culicosporidae' then project := 'MicrosporidiaDB';
            when 'dubosqiidae' then project := 'MicrosporidiaDB';
            when 'edhazardia' then project := 'MicrosporidiaDB';
            when 'eimeria' then project := 'ToxoDB';
            when 'eimeriidae' then project := 'ToxoDB';
            when 'encephalitozoon' then project := 'MicrosporidiaDB';
            when 'endotrypanum' then project := 'TriTrypDB';
            when 'entamoeba' then project := 'AmoebaDB';
            when 'entamoebidae' then project := 'AmoebaDB';
            when 'enterocytozoonidae' then project := 'MicrosporidiaDB';
            when 'enterocytozoon' then project := 'MicrosporidiaDB';
            when 'giardia' then project := 'GiardiaDB';
            when 'gregarina' then project := 'ToxoDB';
            when 'gregarinidae' then project := 'ToxoDB';
            when 'hamiltosporidium' then project := 'MicrosporidiaDB';
            when 'hammondia' then project := 'ToxoDB';
            when 'hexamitidae' then project := 'GiardiaDB';
            when 'hominidae' then project := 'HostDB';
            when 'homo' then project := 'HostDB';
            when 'leishmania' then project := 'TriTrypDB';
            when 'muridae' then project := 'HostDB';
            when 'mus' then project := 'HostDB';
            when 'naegleria' then project := 'AmoebaDB';
            when 'nematocida' then project := 'MicrosporidiaDB';
            when 'neospora' then project := 'ToxoDB';
            when 'nosema' then project := 'MicrosporidiaDB';
            when 'nosematidae' then project := 'MicrosporidiaDB';
            when 'plasmodium' then project := 'PlasmoDB';
            when 'pleistophoridae' then project := 'MicrosporidiaDB';
            when 'sarcocystidae' then project := 'ToxoDB';
            when 'sarcocystis' then project := 'ToxoDB';
            when 'theileria' then project := 'PiroplasmaDB';
            when 'theileriidae' then project := 'PiroplasmaDB';
            when 'toxoplasma' then project := 'ToxoDB';
            when 'trichomonas' then project := 'TrichDB';
            when 'trypanosoma' then project := 'TriTrypDB';
            when 'trypanosomatidae' then project := 'TriTrypDB';
            when 'tubulinosematidae' then project := 'MicrosporidiaDB';
            when 'unikaryonidae' then project := 'MicrosporidiaDB';
            when 'vahlkampfiidae' then project := 'AmoebaDB';
            when 'vavraia' then project := 'MicrosporidiaDB';
            when 'vittaforma' then project := 'MicrosporidiaDB';
            else raise_application_error(-20101,
                                            'project_id("'
                                            || organism || '"): unknown project assignment' );
      end case;
      end if;

    return project;

end project_id;
/

show errors;

GRANT execute ON apidb.project_id TO public;

-------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION apidb.url_escape (url varchar2)
RETURN varchar2
IS
    rslt varchar2(4000);
begin
    rslt := replace(replace(replace(replace(utl_url.escape(url, TRUE, 'UTF-8'),'%20','+'),'(','%28'),')','%29'),'''','%27');
    return rslt;
end url_escape;
/

GRANT execute ON apidb.url_escape TO gus_r;
GRANT execute ON apidb.url_escape TO gus_w;

-------------------------------------------------------------------------------
/* ========================================================================== *
 * gff_format_sequence function
 * format sequence strings for GFF3 report format
 * ========================================================================== */
CREATE OR REPLACE FUNCTION apidb.gff_format_sequence (id varchar2, seq clob)
RETURN clob
IS
    rslt clob;
    idx  number;
begin
    if seq is not null
    then
        if regexp_like(id, '^apidb\|')
        then rslt := '>';
        else rslt := '>apidb|';
        end if;

        rslt := rslt || id || chr(10);

        idx := 1;
        while idx <= length(seq)
        loop
           rslt := rslt || substr(seq, idx, 60) || chr(10);
           idx := idx + 60;
        end loop;
    end if;
    return rslt;
end gff_format_sequence;
/

GRANT execute ON apidb.gff_format_sequence TO gus_r;
GRANT execute ON apidb.gff_format_sequence TO gus_w;

-------------------------------------------------------------------------------
create or replace function apidb.syntenic_location_mapping (syntenic_point in number,
                                                            left_ref_loc in number,
                                                            right_ref_loc in number,
                                                            left_syntenic_loc in number,
                                                            right_syntenic_loc in number,
                                                            syn_is_reversed in number)
return number
-- this function lets Gbrowse map a location in a syntenic region onto the
-- reference space, using a linear interpolation (or extrapolation) from two
-- pairs of "anchor" points which align.
is
    offset number;
    scaling_factor number;
begin
    -- It seems wrong that the scaling factor is different when the synteny is
    -- reversed, but this is how the existing SQL worked. Changes here require
    -- parallel changes in the calling SQL, which checks that the divisor is not zero.
    if syn_is_reversed = 0
    then
            scaling_factor := (right_ref_loc - left_ref_loc + 1) / (right_syntenic_loc - left_syntenic_loc + 1);
    else
            scaling_factor := (right_ref_loc - left_ref_loc + 1) / (right_syntenic_loc - left_syntenic_loc - 1);
    end if;

    offset := (syntenic_point - left_syntenic_loc) * scaling_factor;

    return round(left_ref_loc + offset);
end syntenic_location_mapping;
/

show errors;

GRANT execute ON apidb.syntenic_location_mapping TO gus_r;
GRANT execute ON apidb.syntenic_location_mapping TO gus_w;

-------------------------------------------------------------------------------
create or replace function apidb.compute_startm (syn_is_reversed in number,
                                              start_min in number,
                                              end_max in number,
                                              left_ref_loc in number,
                                              right_ref_loc in number,
                                              left_syntenic_loc in number,
                                              right_syntenic_loc in number,
                                              b_start in number,
                                              b_end in number)
return number
-- this function, a companion to compute_end, lets Gbrowse map a feature in a
-- syntenic region onto the reference space, by choosing a starting location
-- (in syntenic space) and passing it to syntenic_location_mapping
is
    syntenic_min   number;
    syntenic_max   number;
    syntenic_point number;
begin
    -- trim the syntenic gene as needed to fit onto the region of synteny
    syntenic_min := greatest(start_min, b_start);
    syntenic_max := least(end_max, b_end);

    -- which end of the gene is the "start" in reference space?
    syntenic_point := case when syn_is_reversed = 0 then syntenic_min else syntenic_max end;

    return syntenic_location_mapping(syntenic_point, left_ref_loc, right_ref_loc, left_syntenic_loc, right_syntenic_loc, syn_is_reversed);

end compute_startm;
/

show errors;

GRANT execute ON apidb.compute_startm TO gus_r;
GRANT execute ON apidb.compute_startm TO gus_w;

-------------------------------------------------------------------------------
create or replace function apidb.compute_end (syn_is_reversed in number,
                                              start_min in number,
                                              end_max in number,
                                              left_ref_loc in number,
                                              right_ref_loc in number,
                                              left_syntenic_loc in number,
                                              right_syntenic_loc in number,
                                              b_start in number,
                                              b_end in number)
return number
-- this function, a companion to compute_start, lets Gbrowse map a feature in a
-- syntenic region onto the reference space, by choosing an end location
-- (in syntenic space) and passing it to syntenic_location_mapping
is
    syntenic_min   number;
    syntenic_max   number;
    syntenic_point number;
begin
    -- trim the syntenic gene as needed to fit onto the region of synteny
    syntenic_min := greatest(start_min, b_start);
    syntenic_max := least(end_max, b_end);

    -- which end of the gene is the "end" in reference space?
    syntenic_point := case when syn_is_reversed = 0 then syntenic_max else syntenic_min end;

    return syntenic_location_mapping(syntenic_point, left_ref_loc, right_ref_loc, left_syntenic_loc, right_syntenic_loc, syn_is_reversed);

end compute_end;
/

show errors;

GRANT execute ON apidb.compute_end TO gus_r;
GRANT execute ON apidb.compute_end TO gus_w;

-------------------------------------------------------------------------------
create or replace procedure apidb.deletifySeqVarExtDbRls (extDbRlsId in number)
as
  cursor c1 is
      select rowid from dots.SeqVariation where external_database_release_id = extDbRlsId;

  my_rowid urowid;
  recordCount number;
begin
  open c1;
  recordCount := 0;
  loop
    fetch c1 into my_rowid;
    exit when c1%notfound;

    update dots.SeqVariation
    set subclass_view = 'deleteSeqVariation'
    where rowid = my_rowid;

    recordCount := recordCount + 1;
    if mod(recordCount, 1000) = 0 then
        commit;
        -- dbms_output.put_line( recordCount || ' SeqVariations deletified for external_database_release_id ' || extDbRlsId);
    end if;
  end loop;
end;
/

show errors

grant execute on apidb.deletifySeqVarExtDbRls to gus_r;
grant execute on apidb.deletifySeqVarExtDbRls to gus_w;
-------------------------------------------------------------------------------

exit
