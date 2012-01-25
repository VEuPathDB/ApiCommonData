create or replace function apidb.reverse_complement_clob (seq clob)
return clob
is
    rslt clob;
    idx  number;
    base char;
begin
    rslt := '';
    if seq is not null
    then
        for idx IN 1 .. length(seq)
        loop
            base := substr(seq, idx, 1);
            case upper(base)
                when 'A' then rslt := 'T' || rslt;
                when 'C' then rslt := 'G' || rslt;
                when 'G' then rslt := 'C' || rslt;
                when 'T' then rslt := 'A' || rslt;
                else rslt := base || rslt;
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
create or replace procedure
apidb.apidb_unanalyzed_stats
is

tab_count   SMALLINT;
ind_count   SMALLINT;

begin
    for s in (select distinct(owner) schema from all_tables where owner in ('APIDB', 'APIDBTUNING') )
	loop
		dbms_output.put_line('Checking stats for the '||s.schema||' schema');
		for t in (select distinct(table_name) from
					(select distinct(table_name) table_name from all_tables where owner = s.schema and last_analyzed is null
				  			union
				  	 select distinct(table_name) table_name from all_indexes where table_owner = s.schema and last_analyzed is null))
		loop
			dbms_stats.unlock_table_stats(ownname => s.schema, tabname => t.table_name);
			select count(table_name) into tab_count from all_tables
				where owner = s.schema and table_name = t.table_name and last_analyzed is null;
			if tab_count >0 then
			   dbms_output.put_line( '  Updating stats for table '||t.table_name );
			   dbms_stats.gather_table_stats(ownname => s.schema, tabname => t.table_name, estimate_percent => 100, degree => 2);
			end if;
			for i in (select distinct(index_name) index_name from all_indexes where owner = s.schema and table_name = t.table_name and last_analyzed is null and INDEX_TYPE != 'DOMAIN')
		    loop
			    dbms_output.put_line( '    Updating stats for index '||i.index_name );
			    dbms_stats.gather_index_stats(ownname => s.schema, indname => i.index_name, estimate_percent => 100, degree => 2);
		    end loop;
			dbms_stats.lock_table_stats(ownname => s.schema, tabname => t.table_name);
		end loop;
	end loop;
end;
/

show errors
GRANT execute ON apidb.apidb_unanalyzed_stats TO gus_r;
GRANT execute ON apidb.apidb_unanalyzed_stats TO gus_w;

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
   project varchar2(80);
begin

    -- check organism table
    begin

      select distinct project_name
      into project
      from apidb.Organism o, sres.TaxonName tn
      where o.taxon_id = tn.taxon_id
        and tn.name = organism;

    exception

      when NO_DATA_FOUND then
         -- use hardwired genus->project mappings
         case substr(lower(organism), 1, instr(organism||' ', ' ') - 1)
               when 'theileria'
                 then project := 'PiroplasmaDB';
               when 'babesia'
                 then project := 'PiroplasmaDB';
               when 'cryptosporidium'
                 then project := 'CryptoDB';
               when 'plasmodium'
                 then project := 'PlasmoDB';
               when 'toxoplasma'
                 then project := 'ToxoDB';
               when 'neospora'
                 then project := 'ToxoDB';
               when 'endotrypanum'
                 then project := 'TriTrypDB';
               when 'leishmania'
                 then project := 'TriTrypDB';
               when 'trypanosoma'
                 then project := 'TriTrypDB';
               when 'crithidia'
                 then project := 'TriTrypDB';
               when 'trichomonas'
                 then project := 'TrichDB';
               when 'phytomonas'
                 then project := 'TrichDB';
               when 'giardia'
                 then project := 'GiardiaDB';
               when 'entamoeba'
                 then project := 'AmoebaDB';
               when 'encephalitozoon'
                 then project := 'MicrosporidiaDB';
               when 'enterocytozoon'
                 then project := 'MicrosporidiaDB';
               when 'anncaliia'
                 then project := 'MicrosporidiaDB';
               when 'edhazardia'
                 then project := 'MicrosporidiaDB';
               when 'nosema'
                 then project := 'MicrosporidiaDB';
               when 'vittaforma'
                 then project := 'MicrosporidiaDB';
               when 'vavraia'
                 then project := 'MicrosporidiaDB';
               when 'nematocida'
                 then project := 'MicrosporidiaDB';
               when 'octosporea'
                 then project := 'MicrosporidiaDB';
               when 'gregarina'
                 then project := 'ToxoDB';
               when 'sarcocystis'
                 then project := 'OrphanDB';
               when 'eimeria'
                 then project := 'ToxoDB';
               when 'gibberella'
                 then project := 'FungiDB';
               when 'neurospora'
                 then project := 'FungiDB';
               when 'cryptococcus'
                 then project := 'FungiDB';
               when 'aspergillus'
                 then project := 'FungiDB';
               when 'coccidioides'
                 then project := 'FungiDB';
               when 'magnaporthe'
                 then project := 'FungiDB';
               when 'candida'
                 then project := 'FungiDB';
               when 'puccinia'
                 then project := 'FungiDB';
               when 'saccharomyces'
                 then project := 'FungiDB';
               when 'fusarium'
                 then project := 'FungiDB';
               when 'rhizopus'
                 then project := 'FungiDB';
               when 'tremella'
                 then project := 'FungiDB';
               else raise_application_error(-20101,
                                            'project_id() function called with unknown organism "'
                                            || organism || '"' );
      end case;
    end;

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

    return left_ref_loc + offset;
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
exit;
