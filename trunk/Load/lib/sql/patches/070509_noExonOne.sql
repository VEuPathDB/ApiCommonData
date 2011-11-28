set pagesize 50000 linesize 140

spool 070509_translationStart.sql

-- forward strand
select 'update dots.TranslatedAaFeature set translation_start = ' ||
       to_char(ef.coding_start - el.start_min + 1) ||
       ' where na_feature_id = ' ||
       to_char(t.na_feature_id) ||
       ' and translation_start is null;'
         as sqlstatement
from dots.ExonFeature ef, dots.NaLocation el, dots.Transcript t,
     dots.GeneFeature gf, dots.NaLocation gl
where ef.parent_id = t.parent_id
  and el.na_feature_id = ef.na_feature_id
  and ef.parent_id = gf.na_feature_id
  and gf.na_feature_id = gl.na_feature_id
  and gl.is_reversed = 0
  and ef.order_number = (select min(order_number) from dots.exonfeature efint 
                         where efint.parent_id = t.parent_id);

-- reverse strand
select 'update dots.TranslatedAaFeature set translation_start = ' ||
       to_char(el.end_max - ef.coding_start + 1) ||
       ' where na_feature_id = ' ||
       to_char(t.na_feature_id) ||
       ' and translation_start is null;'
         as sqlstatement
from dots.ExonFeature ef, dots.NaLocation el, dots.Transcript t,
     dots.GeneFeature gf, dots.NaLocation gl
where ef.parent_id = t.parent_id
  and el.na_feature_id = ef.na_feature_id
  and ef.parent_id = gf.na_feature_id
  and gf.na_feature_id = gl.na_feature_id
  and gl.is_reversed = 1
  and ef.order_number = (select min(order_number) from dots.exonfeature efint 
                         where efint.parent_id = t.parent_id);

spool off
