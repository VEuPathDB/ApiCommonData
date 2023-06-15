-- TODO CREATE OR REPLACE FUNCTION apidb.tab_to_string (p_varchar2_tab  IN  apidb.varchartab, p_delimiter IN  VARCHAR2 DEFAULT ',')
--      consider replacing calls to this with string_agg instead
-- TODO create or replace function apidb.clob_clob_agg
--      used in LoadGenomicssequence.pm only, replace with string_agg instead
-- TODO create or replace procedure apidb.analyze (schema_name IN varchar2, table_name IN varchar2)

-- !!UNUSED CREATE OR REPLACE FUNCTION apidb.tab_to_clob (p_clob_tab IN apidb.varchartab, p_delimiter IN  VARCHAR2 DEFAULT ',')
-- !!UNUSED create or replace function apidb.char_clob_agg
-- !!UNUSED CREATE OR REPLACE FUNCTION apidb.url_escape (url varchar2)
-- !!UNUSED CREATE OR REPLACE FUNCTION apidb.gff_format_sequence (id varchar2, seq clob)
-- !!UNUSED create or replace procedure apidb.delete_by_invocation_id (table_name in varchar2, alg_invoc_list in varchar2)
-- !!UNUSED create or replace procedure apidb.insert_user_allstudies (userid IN NUMBER)

-------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION apidb.reverse_complement_clob(seq text) RETURNS text AS
$body$
DECLARE
    rslt text;
BEGIN
    rslt := '';
    FOR idx IN REVERSE length(seq)..1
        loop
            rslt := rslt || translate(substr(seq, idx, 1), 'atugcyrkmbdhvATUGCYRKMBDHV', 'taacgrymkvhdbTAACGRYMKVHDB');
        end loop;
    return rslt;
end;
$body$
    LANGUAGE PLPGSQL
    IMMUTABLE;

-------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION apidb.reverse_complement(seq text) RETURNS varchar AS
$body$
BEGIN
    return apidb.reverse_complement_clob(seq)::varchar;
end;
$body$
    LANGUAGE PLPGSQL
    IMMUTABLE;

-------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION apidb.alphanumeric_str(in_string text) RETURNS varchar AS
$body$
DECLARE
    rslt varchar(4000);
BEGIN
    rslt := regexp_replace(in_string, '( *[[:punct:]])', '', 'g');
    return rslt;
end;
$body$
    LANGUAGE PLPGSQL
    IMMUTABLE;

-------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION apidb.prefixed_project_id(organism varchar, prefix varchar) RETURNS varchar AS
$body$
DECLARE
    project varchar(80);
BEGIN
    begin
        EXECUTE
            'select max(project_id) ' ||
            'from ApidbTuning.' || prefix || 'ProjectTaxon pt ' ||
            'where pt.taxon = substr(lower('''
                || replace(replace(regexp_replace(
                   replace(organism, '''', ''),
                   '^\[', ''),
                   'uncultured_', 'uncultured '), 'unclassified ', '')
                || '''), 1, length(pt.taxon)) '
        INTO STRICT project;
    EXCEPTION
        WHEN no_data_found THEN
            RAISE EXCEPTION '%', 'Cannot map the taxon name "' || organism || '" to a component project' USING ERRCODE = '45101';
    END;
    RETURN project;
END;
$body$
    LANGUAGE PLPGSQL
    IMMUTABLE;

-------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION apidb.project_id(organism varchar) RETURNS varchar AS
$body$
BEGIN
    RETURN apidb.prefixed_project_id(organism, '');
END;
$body$
    LANGUAGE PLPGSQL
    IMMUTABLE;

-------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION apidb.arcsinh(x numeric) RETURNS numeric AS
$body$
BEGIN
    RETURN ln((1 + (50 * x)) + sqrt(power(1 + (x * 50), 2) + 1));
END;
$body$
    LANGUAGE PLPGSQL
    IMMUTABLE;

-------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION apidb.arcsinh_to_linear(x numeric) RETURNS numeric AS
$body$
BEGIN
    RETURN (-1 + (exp(x) - exp(-x)) / 2) / 50;
END;
$body$
    LANGUAGE PLPGSQL
    IMMUTABLE;

-------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION apidb.syntenic_location_mapping(syntenic_point     numeric, left_ref_loc numeric,
                                                           right_ref_loc      numeric, left_syntenic_loc numeric,
                                                           right_syntenic_loc numeric,
                                                           syn_is_reversed    numeric) RETURNS numeric AS
$body$
DECLARE
    loc_offset     numeric;
    scaling_factor numeric;
BEGIN
    scaling_factor := (right_ref_loc - left_ref_loc + 1)
        / (abs(right_syntenic_loc - left_syntenic_loc) + 1);
    loc_offset := (syntenic_point - left_syntenic_loc)
        * (case when syn_is_reversed = 1 then -1 else 1 end)
        * scaling_factor;
    return round(left_ref_loc + loc_offset);
end;
$body$
    LANGUAGE PLPGSQL
    IMMUTABLE;

-------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION apidb.compute_end(syn_is_reversed    numeric, start_min numeric, end_max numeric,
                                             left_ref_loc       numeric, right_ref_loc numeric,
                                             left_syntenic_loc  numeric, right_syntenic_loc numeric, b_start numeric,
                                             b_end              numeric) RETURNS numeric AS
$body$
DECLARE
    syntenic_min   numeric;
    syntenic_max   numeric;
    syntenic_point numeric;
BEGIN
    -- trim the syntenic gene as needed to fit onto the region of synteny
    syntenic_min := greatest(start_min, b_start);
    syntenic_max := least(end_max, b_end);
    -- which end of the gene is the "end" in reference space?
    syntenic_point := case when syn_is_reversed = 0 then syntenic_max else syntenic_min end;
    return apidb.syntenic_location_mapping(syntenic_point, left_ref_loc, right_ref_loc, left_syntenic_loc,
                                           right_syntenic_loc, syn_is_reversed);
end;
$body$
    LANGUAGE PLPGSQL
    IMMUTABLE;

-------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION apidb.compute_startm(syn_is_reversed   numeric, start_min numeric, end_max numeric,
                                                left_ref_loc      numeric, right_ref_loc numeric,
                                                left_syntenic_loc numeric, right_syntenic_loc numeric, b_start numeric,
                                                b_end             numeric) RETURNS numeric AS
$body$
DECLARE
    syntenic_min   numeric;
    syntenic_max   numeric;
    syntenic_point numeric;
BEGIN
    -- trim the syntenic gene as needed to fit onto the region of synteny
    syntenic_min := greatest(start_min, b_start);
    syntenic_max := least(end_max, b_end);
    -- which end of the gene is the "start" in reference space?
    syntenic_point := case when syn_is_reversed = 0 then syntenic_min else syntenic_max end;
    return apidb.syntenic_location_mapping(syntenic_point, left_ref_loc, right_ref_loc, left_syntenic_loc,
                                           right_syntenic_loc, syn_is_reversed);
end;
$body$
    LANGUAGE PLPGSQL
    IMMUTABLE;

-------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION apidb.wrap(seq text) RETURNS text AS
$body$
DECLARE
    rslt      text;
    maxchunk  int;
    linesize  int;
    delimiter char;
BEGIN
    linesize := 60;
    delimiter := chr(10);
    IF seq IS NULL OR length(seq) <= linesize
    THEN
        rslt := seq;
    ELSE
        rslt := '';
        maxchunk := ceil(length(seq) / linesize :: float) - 1;
        FOR idx IN 0 .. maxchunk
            LOOP
                IF idx > 0
                THEN
                    rslt := rslt || delimiter;
                END IF;
                rslt := rslt || substr(seq, idx * linesize + 1, linesize);
            END LOOP;
    END IF;
    RETURN rslt;
END;
$body$
    LANGUAGE PLPGSQL
    IMMUTABLE;

-------------------------------------------------------------------------------
-- determine whether the value of a string can be converted to a number
--
-- remove any commas first (under the assumption they're American-style group separators,
-- rather than European-style decimal points
--
-- return 0 or 1
CREATE OR REPLACE FUNCTION apidb.is_number(p_val varchar) RETURNS bigint AS
$body$
DECLARE
    v_val bigint;
BEGIN
    BEGIN
        SELECT (REPLACE(p_val, ',', ''))::numeric
        INTO STRICT v_val;
        RETURN 1;
    EXCEPTION
        WHEN data_exception
            THEN
                RETURN 0;
        WHEN OTHERS
            THEN
                RETURN 1;
    END;
END;
$body$
    LANGUAGE PLPGSQL
    IMMUTABLE;

-------------------------------------------------------------------------------
-- convert a string to a number, then if its absolute value is greater than 0.01,
--    round to 2 places
--
-- remove any commas first (under the assumption they're American-style group separators,
-- rather than European-style decimal points
CREATE OR REPLACE FUNCTION apidb.parse_and_round_number(p_val varchar) RETURNS numeric AS
$body$
DECLARE
    v_val numeric;
BEGIN
    SELECT (REPLACE(p_val, ',', ''))::numeric
    INTO STRICT v_val;
    IF ABS(v_val) >= 0.01
    THEN
        RETURN round(v_val, 2);
    END IF;
    RETURN v_val;
END;
$body$
    LANGUAGE PLPGSQL
    IMMUTABLE;

-------------------------------------------------------------------------------
-- is the given string a valid date with the format 'yyyy-mm-dd'?
CREATE OR REPLACE FUNCTION apidb.is_date(p_val varchar) RETURNS bigint AS
$body$
DECLARE
    v_val timestamp;
BEGIN
    BEGIN
        -- Dates must have the format yyyy-mm-dd, with a four-digit year
        -- and one- or two-digit month and day.
        IF NOT regexp_match(p_val, '^\d\d\d\d-\d\d?-\d\d?$', 'n') IS NOT NULL
        THEN
            RETURN 0;
        END IF;
        SELECT TO_DATE(p_val, 'yyyy-mm-dd')
        INTO STRICT v_val;
        RETURN 1;
    EXCEPTION
        WHEN OTHERS
            THEN
                RETURN 0;
    END;
END;
$body$
    LANGUAGE PLPGSQL
    IMMUTABLE;

-------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION apidb.parse_date(p_val varchar) RETURNS date AS
$body$
DECLARE
    v_val timestamp;
BEGIN
    SELECT TO_DATE(p_val, 'yyyy-mm-dd')
    INTO STRICT v_val;
    RETURN v_val;
END;
$body$
    LANGUAGE PLPGSQL
    IMMUTABLE;

