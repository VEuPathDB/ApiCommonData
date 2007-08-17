set time on timing on

prompt populate dots.ExonFeature.source_id as <parent-source_id>-<exon-number>
update dots.ExonFeature
set source_id = (select gf.source_id || '-' || ef.order_number
                 from dots.GeneFeature gf, dots.ExonFeature ef
                 where gf.na_feature_id = ef.parent_id
                   and ef.na_feature_id = ExonFeature.na_feature_id);

prompt set ExonFeature.is_initial_exon
update dots.ExonFeature
set is_initial_exon = 1
where na_feature_id
      in (select na_feature_id
          from dots.ExonFeature ef
          where ef.order_number
                = (select min(order_number)
                   from dots.ExonFeature ef2
                   where ef.parent_id = ef2.parent_id
                     and ef2.coding_start > 0));

prompt set ExonFeature.is_final_exon
update dots.ExonFeature
set is_final_exon = 1
where na_feature_id
      in (select na_feature_id
          from dots.ExonFeature ef
          where ef.order_number
                = (select max(order_number)
                   from dots.ExonFeature ef2
                   where ef.parent_id = ef2.parent_id
                     and ef2.coding_start > 0));

prompt fix translation_start for forward strand
-- simply the exon.coding_start - exonloc.start_min + 1

update dots.translatedaafeature taaf
set taaf.translation_start =
    (select ef.coding_start - l.start_min + 1
     from dots.exonfeature ef, dots.nalocation l,dots.transcript t
     where t.na_feature_id = taaf.na_feature_id
       and ef.parent_id = t.parent_id
       and ef.is_initial_exon = 1
       and l.na_feature_id = ef.na_feature_id)
where taaf.na_feature_id
      in (select it.na_feature_id
          from dots.transcript it, dots.genefeature igf, dots.NaLocation il
          where igf.na_feature_id = il.na_feature_id
            and igf.na_feature_id = it.parent_id
            and (il.is_reversed = 0 or il.is_reversed is null));
-- commit;


prompt fix translation_start for reverse strand
-- simply the exonloc.end_max - exon.coding_start + 1

update dots.translatedaafeature taaf
set taaf.translation_start = 
    (select l.end_max - ef.coding_start + 1
     from dots.exonfeature ef, dots.nalocation l,dots.transcript t
     where t.na_feature_id = taaf.na_feature_id
       and ef.parent_id = t.parent_id
       and ef.is_initial_exon = 1
       and l.na_feature_id = ef.na_feature_id)
where taaf.na_feature_id
      in (select it.na_feature_id from dots.transcript it, dots.genefeature igf, dots.NaLocation il
          where igf.na_feature_id = il.na_feature_id
            and igf.na_feature_id = it.parent_id
            and il.is_reversed = 1);

-- commit;

prompt fix translation_stop for forward strand
-- need to get the last exon and compute
-- (transcript sequence.length - (exonloc.end_max - exon.coding_end)

update dots.translatedaafeature taaf
set taaf.translation_stop = 
    (select snas.length - (l.end_max - ef.coding_end)
     from dots.exonfeature ef, dots.nalocation l, dots.transcript t,
          dots.splicednasequence snas
     where t.na_feature_id = taaf.na_feature_id
       and snas.na_sequence_id = t.na_sequence_id
       and ef.parent_id = t.parent_id
       and ef.is_final_exon = 1
       and l.na_feature_id = ef.na_feature_id)
where taaf.na_feature_id
      in (select it.na_feature_id
          from dots.transcript it, dots.genefeature igf, dots.NaLocation il
          where igf.na_feature_id = il.na_feature_id
            and igf.na_feature_id = it.parent_id
            and il.is_reversed = 0);

-- commit;

prompt fix translation_stop for reverse strand
-- need to get the last exon and compute
-- (transcript sequence.length - (exon.coding_end - exonloc.start_min)

update dots.translatedaafeature taaf
set taaf.translation_stop = 
    (select snas.length - (ef.coding_end - l.start_min)
     from dots.exonfeature ef, dots.nalocation l,dots.transcript t,
          dots.splicednasequence snas
     where t.na_feature_id = taaf.na_feature_id
       and snas.na_sequence_id = t.na_sequence_id
       and ef.parent_id = t.parent_id
       and ef.is_final_exon = 1
       and l.na_feature_id = ef.na_feature_id)
where taaf.na_feature_id
      in (select it.na_feature_id
          from dots.transcript it, dots.genefeature igf, dots.NaLocation il
          where igf.na_feature_id = il.na_feature_id
            and igf.na_feature_id = it.parent_id
            and il.is_reversed = 1);


prompt fix translation_start for forward strand, genes with noncoding exon one
-- simply the exon.coding_start - exonloc.start_min + 1

update dots.translatedaafeature taaf
set taaf.translation_start =
    (select ef.coding_start - l.start_min + 1
            + (select nvl(sum(nl.end_max - nl.start_min + 1), 0)
               from dots.NaLocation nl, dots.ExonFeature ef2
               where nl.na_feature_id = ef2.na_feature_id
                 and ef2.parent_id = ef.parent_id
                 and ef2.order_number < ef.order_number)
     from dots.exonfeature ef, dots.nalocation l,dots.transcript t
     where t.na_feature_id = taaf.na_feature_id
       and ef.parent_id = t.parent_id
       and ef.is_initial_exon = 1
       and l.na_feature_id = ef.na_feature_id)
where taaf.na_feature_id
      in (select it.na_feature_id
          from dots.transcript it, dots.genefeature igf, dots.NaLocation il
          where igf.na_feature_id = il.na_feature_id
            and igf.na_feature_id = it.parent_id
            and (il.is_reversed = 0 or il.is_reversed is null))
  and taaf.na_feature_id
      in (select t.na_feature_id
          from dots.Transcript t, dots.ExonFeature ef
          where ef.order_number = 1 and ef.is_initial_exon is null
            and ef.parent_id = t.parent_id);
-- commit;

prompt fix translation_start for reverse strand, genes with noncoding exon one
-- simply the exonloc.end_max - exon.coding_start + 1

update dots.translatedaafeature taaf
set taaf.translation_start = 
    (select l.end_max - ef.coding_start + 1
            + (select nvl(sum(nl.end_max - nl.start_min + 1), 0)
               from dots.NaLocation nl, dots.ExonFeature ef2
               where nl.na_feature_id = ef2.na_feature_id
                 and ef2.parent_id = ef.parent_id
                 and ef2.order_number < ef.order_number)
     from dots.exonfeature ef, dots.nalocation l,dots.transcript t
     where t.na_feature_id = taaf.na_feature_id
       and ef.parent_id = t.parent_id
       and ef.is_initial_exon = 1
       and l.na_feature_id = ef.na_feature_id)
where taaf.na_feature_id
      in (select it.na_feature_id from dots.transcript it, dots.genefeature igf, dots.NaLocation il
          where igf.na_feature_id = il.na_feature_id
            and igf.na_feature_id = it.parent_id
            and il.is_reversed = 1)
  and taaf.na_feature_id
      in (select t.na_feature_id
          from dots.Transcript t, dots.ExonFeature ef
          where ef.order_number = 1 and ef.is_initial_exon is null
            and ef.parent_id = t.parent_id);
-- commit;

prompt fix translation_stop for forward strand, genes with noncoding last exon
-- need to get the last exon and compute
-- (transcript sequence.length - (exonloc.end_max - exon.coding_end)

update dots.translatedaafeature taaf
set taaf.translation_stop = 
    (select snas.length - (l.end_max - ef.coding_end)
            + (select nvl(sum(nl.end_max - nl.start_min + 1), 0)
               from dots.NaLocation nl, dots.ExonFeature ef2
               where nl.na_feature_id = ef2.na_feature_id
                 and ef2.parent_id = ef.parent_id
                 and ef2.order_number > ef.order_number)
     from dots.exonfeature ef, dots.nalocation l, dots.transcript t,
          dots.splicednasequence snas
     where t.na_feature_id = taaf.na_feature_id
       and snas.na_sequence_id = t.na_sequence_id
       and ef.parent_id = t.parent_id
       and ef.is_final_exon = 1
       and l.na_feature_id = ef.na_feature_id)
where taaf.na_feature_id
      in (select it.na_feature_id
          from dots.transcript it, dots.genefeature igf, dots.NaLocation il
          where igf.na_feature_id = il.na_feature_id
            and igf.na_feature_id = it.parent_id
            and il.is_reversed = 0)
  and taaf.na_feature_id
      in (select t.na_feature_id
          from dots.Transcript t, dots.ExonFeature ef
          where ef.coding_start < 0
            and ef.parent_id = t.parent_id);

-- commit;

prompt fix translation_stop for reverse strand, genes with noncoding last exon
-- need to get the last exon and compute
-- (transcript sequence.length - (exon.coding_end - exonloc.start_min)

update dots.translatedaafeature taaf
set taaf.translation_stop = 
    (select snas.length - (ef.coding_end - l.start_min)
            + (select nvl(sum(nl.end_max - nl.start_min + 1), 0)
               from dots.NaLocation nl, dots.ExonFeature ef2
               where nl.na_feature_id = ef2.na_feature_id
                 and ef2.parent_id = ef.parent_id
                 and ef2.order_number > ef.order_number)
     from dots.exonfeature ef, dots.nalocation l,dots.transcript t,
          dots.splicednasequence snas
     where t.na_feature_id = taaf.na_feature_id
       and snas.na_sequence_id = t.na_sequence_id
       and ef.parent_id = t.parent_id
       and ef.is_final_exon = 1
       and l.na_feature_id = ef.na_feature_id)
where taaf.na_feature_id
      in (select it.na_feature_id
          from dots.transcript it, dots.genefeature igf, dots.NaLocation il
          where igf.na_feature_id = il.na_feature_id
            and igf.na_feature_id = it.parent_id
            and il.is_reversed = 1)
  and taaf.na_feature_id
      in (select t.na_feature_id
          from dots.Transcript t, dots.ExonFeature ef
          where ef.coding_start < 0
            and ef.parent_id = t.parent_id);

