create or replace function apidb.reverse_complement_clob(seq TEXT) RETURNS TEXT AS $$
DECLARE    rslt TEXT;
DECLARE    idx  NUMERIC;
DECLARE    base char;
BEGIN
    rslt := '';
    if seq is not null
    then
        for idx IN 1 .. length(seq)
        loop
            base := substr(seq, idx, 1);
            case upper(base)
                when 'A' then rslt := 'T' || rslt;
                when 'T' then rslt := 'A' || rslt;
                when 'U' then rslt := 'A' || rslt;
                when 'G' then rslt := 'C' || rslt;
                when 'C' then rslt := 'G' || rslt;
                when 'Y' then rslt := 'R' || rslt;
                when 'R' then rslt := 'Y' || rslt;
                when 'S' then rslt := 'S' || rslt;
                when 'W' then rslt := 'W' || rslt;
                when 'K' then rslt := 'M' || rslt;
                when 'M' then rslt := 'K' || rslt;
                when 'B' then rslt := 'V' || rslt;
                when 'D' then rslt := 'H' || rslt;
                when 'H' then rslt := 'D' || rslt;
                when 'V' then rslt := 'B' || rslt;
                when 'N' then rslt := 'N' || rslt;
                else rslt := base || rslt;
            end case;
        end loop;
    end if;
    return rslt;
END;
$$
LANGUAGE 'plpgsql';


-------------------------------------------------------------------------------

-- select apidb.reverse_complement('ATCG');

create or replace function apidb.reverse_complement (seq varchar) RETURNS varchar AS $$
DECLARE rslt varchar(4000);
DECLARE idx    NUMERIC;
begin
    rslt := '';
    if seq is not null
    then
        for idx IN 1 .. length(seq)
        loop
            case upper(substr(seq, idx, 1))
                when 'A' then rslt := 'T' || rslt;
                when 'T' then rslt := 'A' || rslt;
                when 'U' then rslt := 'A' || rslt;
                when 'G' then rslt := 'C' || rslt;
                when 'C' then rslt := 'G' || rslt;
                when 'Y' then rslt := 'R' || rslt;
                when 'R' then rslt := 'Y' || rslt;
                when 'S' then rslt := 'S' || rslt;
                when 'W' then rslt := 'W' || rslt;
                when 'K' then rslt := 'M' || rslt;
                when 'M' then rslt := 'K' || rslt;
                when 'B' then rslt := 'V' || rslt;
                when 'D' then rslt := 'H' || rslt;
                when 'H' then rslt := 'D' || rslt;
                when 'V' then rslt := 'B' || rslt;
                when 'N' then rslt := 'N' || rslt;
                else rslt := substr(seq, idx, 1) || rslt;
            end case;
        end loop;
    end if;
    return rslt;
end
$$
LANGUAGE 'plpgsql';


-------------------------------------------------------------------------------

-- I don't think we need varchartab and tab_to_string.
-- instead of
--    apidb.tab_to_string(CAST(COLLECT(ec_number order by ec_number) AS apidb.varchartab)
-- do
--    array_to_string(array_agg(distinct(ec_number order by ec_number))
-- 

CREATE TYPE apidb.varchartab AS (str varchar(4000));


CREATE OR REPLACE FUNCTION
apidb.tab_to_string (p_varchar_tab  IN  apidb.varchartab,
                     p_delimiter     IN  varchar DEFAULT ',')
RETURNS varchar AS $$
DECLARE l_string     varchar(32767);
BEGIN

  IF p_varchar_tab.FIRST IS NULL THEN
    RETURN null;
  END IF;

  FOR i IN p_varchar_tab.FIRST .. p_varchar_tab.LAST LOOP
    IF i != p_varchar_tab.FIRST AND length(l_string) < 4000 THEN
      l_string := l_string || p_delimiter;
    END IF;

    IF length(l_string) >= 3997 THEN
      l_string := SUBSTR(l_string, 1, 3997) ||  '...' ;
    ELSIF (length(l_string) + length(p_varchar_tab(i))) > 4000 THEN
      l_string := l_string || SUBSTR(p_varchar_tab(i), 1, 3997 - length(l_string)) || '...' ;
    ELSE
      l_string := l_string || p_varchar_tab(i);
    END IF;
  END LOOP;

  RETURN l_string;

END
$$
LANGUAGE 'plpgsql';


-------------------------------------------------------------------------------
-- ora-only --create or replace procedure
-- ora-only --apidb.apidb_unanalyzed_stats
-- ora-only --is
-- ora-only --
-- ora-only --tab_count   SMALLINT;
-- ora-only --ind_count   SMALLINT;
-- ora-only --
-- ora-only --begin
-- ora-only --    for s in (select distinct(owner) schema from all_tables where owner in ('APIDB') )
-- ora-only --	loop
-- ora-only --		dbms_output.put_line('Checking stats for the '||s.schema||' schema');
-- ora-only --		for t in (select distinct(table_name) from
-- ora-only --					(select distinct(table_name) table_name from all_tables where owner = s.schema and last_analyzed is null
-- ora-only --				  			union
-- ora-only --				  	 select distinct(table_name) table_name from all_indexes where table_owner = s.schema and last_analyzed is null))
-- ora-only --		loop
-- ora-only --			dbms_stats.unlock_table_stats(ownname => s.schema, tabname => t.table_name);
-- ora-only --			select count(table_name) into tab_count from all_tables
-- ora-only --				where owner = s.schema and table_name = t.table_name and last_analyzed is null;
-- ora-only --			if tab_count >0 then
-- ora-only --			   dbms_output.put_line( '  Updating stats for table '||t.table_name );
-- ora-only --			   dbms_stats.gather_table_stats(ownname => s.schema, tabname => t.table_name, estimate_percent => 100, degree => 2);
-- ora-only --			end if;
-- ora-only --			for i in (select distinct(index_name) index_name from all_indexes where owner = s.schema and table_name = t.table_name and last_analyzed is null and INDEX_TYPE != 'DOMAIN')
-- ora-only --		    loop
-- ora-only --			    dbms_output.put_line( '    Updating stats for index '||i.index_name );
-- ora-only --			    dbms_stats.gather_index_stats(ownname => s.schema, indname => i.index_name, estimate_percent => 100, degree => 2);
-- ora-only --		    end loop;
-- ora-only --			dbms_stats.lock_table_stats(ownname => s.schema, tabname => t.table_name);
-- ora-only --		end loop;
-- ora-only --	end loop;
-- ora-only --end;
-- ora-only --/
-- ora-only --
-- ora-only --show errors
-- ora-only --GRANT execute ON apidb.apidb_unanalyzed_stats TO gus_r;
-- ora-only --GRANT execute ON apidb.apidb_unanalyzed_stats TO gus_w;

-------------------------------------------------------------------------------
/* ========================================================================== *
 * char_clob_agg function
 * aggregate varchar rows into a clob; delimited by new line
 * ========================================================================== */
-- ora-only --create or replace type apidb.char_clob_agg_type as object
-- ora-only --(
-- ora-only --  char_content varchar(29990),
-- ora-only --  clob_content clob,
-- ora-only --  delimiter char(1),
-- ora-only --
-- ora-only --  static function ODCIAggregateInitialize
-- ora-only --    ( sctx in out NOCOPY  char_clob_agg_type )
-- ora-only --    return NUMERIC ,
-- ora-only --
-- ora-only --  member function ODCIAggregateIterate
-- ora-only --    ( self  in out NOCOPY char_clob_agg_type ,
-- ora-only --      value in            varchar
-- ora-only --    ) return NUMERIC ,
-- ora-only --
-- ora-only --  member function ODCIAggregateTerminate
-- ora-only --    ( self        in  char_clob_agg_type,
-- ora-only --      returnvalue out NOCOPY clob,
-- ora-only --      flags       in  NUMERIC
-- ora-only --    ) return NUMERIC ,
-- ora-only --
-- ora-only --  member function ODCIAggregateMerge
-- ora-only --    ( self in out NOCOPY char_clob_agg_type,
-- ora-only --      ctx2 in            char_clob_agg_type
-- ora-only --    ) return NUMERIC
-- ora-only --);
-- ora-only --/
-- ora-only --
-- ora-only --create or replace type body apidb.char_clob_agg_type
-- ora-only --is
-- ora-only --
-- ora-only --  static function ODCIAggregateInitialize
-- ora-only --  ( sctx in out NOCOPY char_clob_agg_type )
-- ora-only --  return NUMERIC
-- ora-only --  is
-- ora-only --  begin
-- ora-only --
-- ora-only --    sctx := char_clob_agg_type(NULL, NULL, chr(10)) ;
-- ora-only --    dbms_lob.createtemporary(sctx.clob_content, true);
-- ora-only --
-- ora-only --    return ODCIConst.Success ;
-- ora-only --
-- ora-only --  end;
-- ora-only --
-- ora-only --  member function ODCIAggregateIterate
-- ora-only --  ( self  in out NOCOPY char_clob_agg_type ,
-- ora-only --    value in            varchar
-- ora-only --  ) return NUMERIC
-- ora-only --  is
-- ora-only --    current_length NUMERIC;
-- ora-only --    input_length NUMERIC;
-- ora-only --  begin
-- ora-only --
-- ora-only --    current_length := length(self.char_content);
-- ora-only --    input_length := length(value);
-- ora-only --    IF current_length + input_length > 29900 THEN
-- ora-only --      IF dbms_lob.getlength(self.clob_content) > 0 THEN
-- ora-only --        dbms_lob.writeappend(self.clob_content, 1, self.delimiter);
-- ora-only --      END IF;
-- ora-only --      dbms_lob.writeappend(self.clob_content, current_length, self.char_content);
-- ora-only --      self.char_content := value;
-- ora-only --    ELSIF input_length > 0 THEN
-- ora-only --      IF current_length > 0 THEN
-- ora-only --        self.char_content := self.char_content || self.delimiter;
-- ora-only --      END IF;
-- ora-only --      self.char_content := self.char_content || value;
-- ora-only --    END IF;
-- ora-only --
-- ora-only --    return ODCIConst.Success;
-- ora-only --
-- ora-only --  end;
-- ora-only --
-- ora-only --  member function ODCIAggregateTerminate
-- ora-only --  ( self        in         char_clob_agg_type ,
-- ora-only --    returnvalue out NOCOPY clob ,
-- ora-only --    flags       in         NUMERIC
-- ora-only --  ) return NUMERIC
-- ora-only --  is
-- ora-only --    char_length NUMERIC;
-- ora-only --  begin
-- ora-only --
-- ora-only --    char_length := length(self.char_content);
-- ora-only --    returnValue := self.clob_content;
-- ora-only --    IF char_length > 0 THEN
-- ora-only --      IF dbms_lob.getlength(returnValue) > 0 THEN
-- ora-only --        dbms_lob.writeappend(returnValue, 1, self.delimiter);
-- ora-only --      END IF;
-- ora-only --      dbms_lob.writeappend(returnValue, char_length, self.char_content);
-- ora-only --    END IF;
-- ora-only --
-- ora-only --    return ODCIConst.Success;
-- ora-only --
-- ora-only --  end;
-- ora-only --
-- ora-only --  member function ODCIAggregateMerge
-- ora-only --  ( self in out NOCOPY char_clob_agg_type ,
-- ora-only --    ctx2 in            char_clob_agg_type
-- ora-only --  ) return NUMERIC
-- ora-only --  is
-- ora-only --    current_length NUMERIC;
-- ora-only --    input_length NUMERIC;
-- ora-only --  begin
-- ora-only --   
-- ora-only --    current_length := length(self.char_content);
-- ora-only --    input_length := length(ctx2.char_content);
-- ora-only --    IF dbms_lob.getlength(ctx2.clob_content) > 0 THEN
-- ora-only --     IF dbms_lob.getlength(self.clob_content) > 0 THEN
-- ora-only --        dbms_lob.writeappend(self.clob_content, 1, self.delimiter);
-- ora-only --      END IF;
-- ora-only --      IF current_length > 0 THEN
-- ora-only --        dbms_lob.writeappend(self.clob_content, current_length + 1, self.char_content || self.delimiter);
-- ora-only --      END IF;
-- ora-only --      dbms_lob.append(self.clob_content, ctx2.clob_content);
-- ora-only --      self.char_content := ctx2.char_content;
-- ora-only --    ELSIF current_length + input_length > 29900 THEN
-- ora-only --      IF dbms_lob.getlength(self.clob_content) > 0 THEN
-- ora-only --        dbms_lob.writeappend(self.clob_content, 1, self.delimiter);
-- ora-only --      END IF;
-- ora-only --      dbms_lob.writeappend(self.clob_content, current_length, self.char_content);
-- ora-only --      self.char_content := ctx2.char_content;
-- ora-only --    ELSIF input_length > 0 THEN
-- ora-only --      IF current_length > 0 THEN
-- ora-only --          self.char_content := self.char_content || self.delimiter;
-- ora-only --      END IF;
-- ora-only --      self.char_content := self.char_content || ctx2.char_content;
-- ora-only --    END IF;
-- ora-only --    
-- ora-only --    return ODCIConst.Success;
-- ora-only --
-- ora-only --  end;
-- ora-only --
-- ora-only --end;
-- ora-only --/
-- ora-only --
-- ora-only --create or replace function apidb.char_clob_agg
-- ora-only --  ( input varchar )
-- ora-only --  return clob
-- ora-only --  deterministic
-- ora-only --  parallel_enable
-- ora-only --  aggregate using char_clob_agg_type
-- ora-only --;
-- ora-only --/
-- ora-only --
-- ora-only --grant execute on apidb.char_clob_agg to public;
-- ora-only --
-- ora-only ---------------------------------------------------------------------------------
-- ora-only --/* ========================================================================== *
-- ora-only -- * clob_clob_agg function
-- ora-only -- * aggregate clob rows into a clob; delimited by new line
-- ora-only -- * ========================================================================== */
-- ora-only --create or replace type apidb.clob_clob_agg_type as object
-- ora-only --(
-- ora-only --  clob_content clob,
-- ora-only --  delimiter char(1),
-- ora-only --
-- ora-only --  static function ODCIAggregateInitialize
-- ora-only --    ( sctx in out NOCOPY  clob_clob_agg_type )
-- ora-only --    return NUMERIC ,
-- ora-only --
-- ora-only --  member function ODCIAggregateIterate
-- ora-only --    ( self  in out NOCOPY clob_clob_agg_type ,
-- ora-only --      value in            CLOB
-- ora-only --    ) return NUMERIC ,
-- ora-only --
-- ora-only --  member function ODCIAggregateTerminate
-- ora-only --    ( self        in  clob_clob_agg_type,
-- ora-only --      returnvalue out NOCOPY CLOB,
-- ora-only --      flags       in  NUMERIC
-- ora-only --    ) return NUMERIC ,
-- ora-only --
-- ora-only --  member function ODCIAggregateMerge
-- ora-only --    ( self in out NOCOPY clob_clob_agg_type,
-- ora-only --      ctx2 in            clob_clob_agg_type
-- ora-only --    ) return NUMERIC
-- ora-only --);
-- ora-only --/
-- ora-only --
-- ora-only --create or replace type body apidb.clob_clob_agg_type
-- ora-only --is
-- ora-only --
-- ora-only --  static function ODCIAggregateInitialize
-- ora-only --  ( sctx in out NOCOPY clob_clob_agg_type )
-- ora-only --  return NUMERIC
-- ora-only --  is
-- ora-only --  begin
-- ora-only --
-- ora-only --    sctx := clob_clob_agg_type(NULL, chr(10)) ;
-- ora-only --    dbms_lob.createtemporary(sctx.clob_content, true);
-- ora-only --
-- ora-only --    return ODCIConst.Success ;
-- ora-only --
-- ora-only --  end;
-- ora-only --
-- ora-only --  member function ODCIAggregateIterate
-- ora-only --  ( self  in out NOCOPY clob_clob_agg_type ,
-- ora-only --    value in            CLOB
-- ora-only --  ) return NUMERIC
-- ora-only --  is
-- ora-only --    current_length NUMERIC;
-- ora-only --    input_length NUMERIC;
-- ora-only --  begin
-- ora-only --
-- ora-only --
-- ora-only --    current_length := dbms_lob.getlength(self.clob_content);
-- ora-only --    input_length   := dbms_lob.getlength(value);
-- ora-only --
-- ora-only --    IF input_length > 0 THEN
-- ora-only --      IF current_length > 0 THEN
-- ora-only --        dbms_lob.writeappend(self.clob_content, 1, self.delimiter);
-- ora-only --      END IF;
-- ora-only --      dbms_lob.append(self.clob_content, value);
-- ora-only --    END IF;
-- ora-only --
-- ora-only --    return ODCIConst.Success;
-- ora-only --
-- ora-only --  end;
-- ora-only --
-- ora-only --  member function ODCIAggregateTerminate
-- ora-only --  ( self        in         clob_clob_agg_type ,
-- ora-only --    returnValue out NOCOPY CLOB ,
-- ora-only --    flags       in         NUMERIC
-- ora-only --  ) return NUMERIC
-- ora-only --  is
-- ora-only --    char_length NUMERIC;
-- ora-only --  begin
-- ora-only --
-- ora-only --    returnValue := self.clob_content;
-- ora-only --
-- ora-only --    return ODCIConst.Success;
-- ora-only --
-- ora-only --  end;
-- ora-only --
-- ora-only --  member function ODCIAggregateMerge
-- ora-only --  ( self in out NOCOPY clob_clob_agg_type ,
-- ora-only --    ctx2 in            clob_clob_agg_type
-- ora-only --  ) return NUMERIC
-- ora-only --  is
-- ora-only --    current_length NUMERIC;
-- ora-only --    input_length NUMERIC;
-- ora-only --  begin
-- ora-only --
-- ora-only --/*   
-- ora-only --    current_length := dbms_lob.getlength(self.clob_content);
-- ora-only --    input_length   := dbms_lob.getlength(ctx2.clob_content);
-- ora-only --    IF input_length > 0 THEN
-- ora-only --      IF current_length > 0 THEN
-- ora-only --        dbms_lob.writeappend(self.clob_content, 1, self.delimiter);
-- ora-only --      END IF;
-- ora-only --      dbms_lob.append(self.clob_content, ctx2.clob_content);
-- ora-only --    END IF;
-- ora-only --*/
-- ora-only --
-- ora-only --    return ODCIConst.Success;
-- ora-only --
-- ora-only --  end;
-- ora-only --
-- ora-only --end;
-- ora-only --/
-- ora-only --
-- ora-only --create or replace function apidb.clob_clob_agg
-- ora-only --  ( input clob )
-- ora-only --  return clob
-- ora-only --  deterministic
-- ora-only --  --parallel_enable
-- ora-only --  aggregate using clob_clob_agg_type
-- ora-only --;
-- ora-only --/
-- ora-only --
-- ora-only --grant execute on apidb.clob_clob_agg to public;

-------------------------------------------------------------------------------

/**** remove all special characters from input string ****/

-- Postgres regexp_replace() syntax != Oracle's
create or replace function apidb.alphanumeric_str(in_string varchar) returns varchar AS $$
DECLARE    rslt varchar(4000);
begin
    rslt := regexp_replace(in_string, '( *[[:punct:]])', '', 'g');
    return rslt;
end
$$
LANGUAGE 'plpgsql';

grant execute on function apidb.alphanumeric_str(in_string varchar) to public;

-------------------------------------------------------------------------------

--
-- instr functions that mimic Oracle's counterpart
-- Syntax: instr(string1, string2, [n], [m]) where [] denotes optional parameters.
-- 
-- Searches string1 beginning at the nth character for the mth occurrence
-- of string2.  If n is negative, search backwards.  If m is not passed,
-- assume 1 (search starts at first character).
--
-- http://www.postgresql.org/docs/7.4/static/plpgsql-porting.html#PLPGSQL-PORTING-APPENDIX

CREATE OR REPLACE FUNCTION instr(varchar, varchar) RETURNS integer AS '
DECLARE
    pos integer;
BEGIN
    pos:= instr($1, $2, 1, 1);
    RETURN pos;
END;
' LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION instr(varchar, varchar, varchar) RETURNS integer AS '
DECLARE
    string ALIAS FOR $1;
    string_to_search ALIAS FOR $2;
    beg_index ALIAS FOR $3;
    pos integer NOT NULL DEFAULT 0;
    temp_str varchar;
    beg integer;
    length integer;
    ss_length integer;
BEGIN
    IF beg_index > 0 THEN
        temp_str := substring(string FROM beg_index);
        pos := position(string_to_search IN temp_str);

        IF pos = 0 THEN
            RETURN 0;
        ELSE
            RETURN pos + beg_index - 1;
        END IF;
    ELSE
        ss_length := char_length(string_to_search);
        length := char_length(string);
        beg := length + beg_index - ss_length + 2;

        WHILE beg > 0 LOOP
            temp_str := substring(string FROM beg FOR ss_length);
            pos := position(string_to_search IN temp_str);

            IF pos > 0 THEN
                RETURN beg;
            END IF;

            beg := beg - 1;
        END LOOP;

        RETURN 0;
    END IF;
END;
' LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION instr(varchar, varchar, integer, integer) RETURNS integer AS '
DECLARE
    string ALIAS FOR $1;
    string_to_search ALIAS FOR $2;
    beg_index ALIAS FOR $3;
    occur_index ALIAS FOR $4;
    pos integer NOT NULL DEFAULT 0;
    occur_number integer NOT NULL DEFAULT 0;
    temp_str varchar;
    beg integer;
    i integer;
    length integer;
    ss_length integer;
BEGIN
    IF beg_index > 0 THEN
        beg := beg_index;
        temp_str := substring(string FROM beg_index);

        FOR i IN 1..occur_index LOOP
            pos := position(string_to_search IN temp_str);

            IF i = 1 THEN
                beg := beg + pos - 1;
            ELSE
                beg := beg + pos;
            END IF;

            temp_str := substring(string FROM beg + 1);
        END LOOP;

        IF pos = 0 THEN
            RETURN 0;
        ELSE
            RETURN beg;
        END IF;
    ELSE
        ss_length := char_length(string_to_search);
        length := char_length(string);
        beg := length + beg_index - ss_length + 2;

        WHILE beg > 0 LOOP
            temp_str := substring(string FROM beg FOR ss_length);
            pos := position(string_to_search IN temp_str);

            IF pos > 0 THEN
                occur_number := occur_number + 1;

                IF occur_number = occur_index THEN
                    RETURN beg;
                END IF;
            END IF;

            beg := beg - 1;
        END LOOP;

        RETURN 0;
    END IF;
END;
' LANGUAGE plpgsql;

-------------------------------------------------------------------------------
-- Oracle-specific instr() function mimicked with custom function above
create or replace function apidb.project_id (organism varchar) returns varchar AS $$
begin
   case substr(lower(organism), 1, instr(organism||' ', ' ') - 1)
         when 'theileria'
           then return 'PiroplasmaDB';
         when 'babesia'
           then return 'PiroplasmaDB';
         when 'cryptosporidium'
           then return 'CryptoDB';
         when 'plasmodium'
           then return 'PlasmoDB';
         when 'toxoplasma'
           then return 'ToxoDB';
         when 'neospora'
           then return 'ToxoDB';
         when 'leishmania'
           then return 'TriTrypDB';
         when 'trypanosoma'
           then return 'TriTrypDB';
         when 'crithidia'
           then return 'TriTrypDB';
         when 'trichomonas'
           then return 'TrichDB';
         when 'phytomonas'
           then return 'TrichDB';
         when 'giardia'
           then return 'GiardiaDB';
         when 'entamoeba'
           then return 'AmoebaDB';
         when 'encephalitozoon'
           then return 'MicrosporidiaDB';
         when 'enterocytozoon'
           then return 'MicrosporidiaDB';
         when 'anncaliia'
           then return 'MicrosporidiaDB';
         when 'edhazardia'
           then return 'MicrosporidiaDB';
         when 'nosema'
           then return 'MicrosporidiaDB';
         when 'vittaforma'
           then return 'MicrosporidiaDB';
         when 'vavraia'
           then return 'MicrosporidiaDB';
         when 'nematocida'
           then return 'MicrosporidiaDB';
         when 'octosporea'
           then return 'MicrosporidiaDB';
         when 'gregarina'
           then return 'ToxoDB';
         when 'sarcocystis'
           then return 'OrphanDB';
         when 'eimeria'
           then return 'ToxoDB';
         when 'gibberella'
           then return 'FungiDB';
         when 'neurospora'
           then return 'FungiDB';
         when 'cryptococcus'
           then return 'FungiDB';
         when 'aspergillus'
           then return 'FungiDB';
         when 'coccidioides'
           then return 'FungiDB';
         when 'magnaporthe'
           then return 'FungiDB';
         when 'candida'
           then return 'FungiDB';
         when 'puccinia'
           then return 'FungiDB';
         when 'saccharomyces'
           then return 'FungiDB';
         when 'fusarium'
           then return 'FungiDB';
         when 'rhizopus'
           then return 'FungiDB';
         else RAISE WARNING 'project_id() function called with unknown organism %"', organism ;
      end case;
end
$$
LANGUAGE 'plpgsql';

-------------------------------------------------------------------------------
-- COMPILES BUT IS INCOMPLETE --
-- need to install postgresql90-plperl.x86_64 RPM package so we can
-- CREATE LANGUAGE plperl;

-- this does nothing until perl is enabled
CREATE OR REPLACE FUNCTION apidb.url_escape_base(url varchar) RETURNS varchar AS $$
--use URI::Escape;
--my $encode = uri_escape($_[0]);
begin
    return url;
end
$$
--LANGUAGE 'plperlu';
LANGUAGE 'plpgsql';

CREATE OR REPLACE FUNCTION apidb.url_escape (url varchar) RETURNS varchar AS $$
DECLARE
    rslt varchar(4000);
begin
    rslt := replace(replace(replace(replace(apidb.url_escape_base(url),'%20','+'),'(','%28'),')','%29'),'''','%27');
    return rslt;
end
$$
LANGUAGE 'plpgsql';

-------------------------------------------------------------------------------
/* ========================================================================== *
 * gff_format_sequence function
 * format sequence strings for GFF3 report format
 * ========================================================================== */
CREATE OR REPLACE FUNCTION apidb.gff_format_sequence (id varchar, seq text)
RETURNS text AS $$
DECLARE
    rslt TEXT;
    idx  INTEGER;
begin
    if seq is not null
    then
        if id ~ E'^apidb\\|'
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
end
$$
LANGUAGE 'plpgsql';




-------------------------------------------------------------------------------
-- select apidb.syntenic_location_mapping(95010, 24088, 47870, 95010, 101529, 0);
-- select apidb.syntenic_location_mapping(14002, 24088, 47870, 95010, 101529, 0);

create or replace function apidb.syntenic_location_mapping (syntenic_point in NUMERIC,
                                                            left_ref_loc in NUMERIC,
                                                            right_ref_loc in NUMERIC,
                                                            left_syntenic_loc in NUMERIC,
                                                            right_syntenic_loc in NUMERIC,
                                                            syn_is_reversed in NUMERIC)
returns NUMERIC(100,2) AS $$
-- this function lets Gbrowse map a location in a syntenic region onto the
-- reference space, using a linear interpolation (or extrapolation) from two
-- pairs of "anchor" points which align.
DECLARE
    offset_n NUMERIC; -- 'offset' is Pg keyword
    scaling_factor NUMERIC;
    location NUMERIC(100,2);
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

    offset_n := (syntenic_point - left_syntenic_loc) * scaling_factor;

    location := left_ref_loc + offset_n;
    return location;
end
$$
LANGUAGE 'plpgsql';


-------------------------------------------------------------------------------

-- select apidb.compute_startm(0, 13039, 14002, 24088, 47870, 95010, 101529, 95010, 101529) from dual;
-- Oracle: 24088

create or replace function apidb.compute_startm (syn_is_reversed in NUMERIC,
                                              start_min in NUMERIC,
                                              end_max in NUMERIC,
                                              left_ref_loc in NUMERIC,
                                              right_ref_loc in NUMERIC,
                                              left_syntenic_loc in NUMERIC,
                                              right_syntenic_loc in NUMERIC,
                                              b_start in NUMERIC,
                                              b_end in NUMERIC)
returns NUMERIC AS $$
-- this function, a companion to compute_end, lets Gbrowse map a feature in a
-- syntenic region onto the reference space, by choosing a starting location
-- (in syntenic space) and passing it to syntenic_location_mapping
DECLARE
    syntenic_min   NUMERIC;
    syntenic_max   NUMERIC;
    syntenic_point NUMERIC;
begin
    -- trim the syntenic gene as needed to fit onto the region of synteny
    syntenic_min := greatest(start_min, b_start);
    syntenic_max := least(end_max, b_end);

    -- which end of the gene is the "start" in reference space?
    syntenic_point := case when syn_is_reversed = 0 then syntenic_min else syntenic_max end;

    return apidb.syntenic_location_mapping(syntenic_point, left_ref_loc, right_ref_loc, left_syntenic_loc, right_syntenic_loc, syn_is_reversed);

end
$$
LANGUAGE 'plpgsql';

-------------------------------------------------------------------------------

-- select apidb.compute_end(0, 13039, 14002, 24088, 47870, 95010, 101529, 95010, 101529) ;
-- Oracle: -271404.83

create or replace function apidb.compute_end (syn_is_reversed in NUMERIC,
                                              start_min in NUMERIC,
                                              end_max in NUMERIC,
                                              left_ref_loc in NUMERIC,
                                              right_ref_loc in NUMERIC,
                                              left_syntenic_loc in NUMERIC,
                                              right_syntenic_loc in NUMERIC,
                                              b_start in NUMERIC,
                                              b_end in NUMERIC)
returns NUMERIC AS $$
-- this function, a companion to compute_start, lets Gbrowse map a feature in a
-- syntenic region onto the reference space, by choosing an end location
-- (in syntenic space) and passing it to syntenic_location_mapping
DECLARE
    syntenic_min   NUMERIC;
    syntenic_max   NUMERIC;
    syntenic_point NUMERIC;
begin
    -- trim the syntenic gene as needed to fit onto the region of synteny
    syntenic_min := greatest(start_min, b_start);
    syntenic_max := least(end_max, b_end);

    -- which end of the gene is the "end" in reference space?
    syntenic_point := case when syn_is_reversed = 0 then syntenic_max else syntenic_min end;

    return apidb.syntenic_location_mapping(syntenic_point, left_ref_loc, right_ref_loc, left_syntenic_loc, right_syntenic_loc, syn_is_reversed);

end
$$
LANGUAGE 'plpgsql';
-------------------------------------------------------------------------------
