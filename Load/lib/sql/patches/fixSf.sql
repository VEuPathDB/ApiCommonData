set time on timing on

-- these update statements fix some problems in data created by the
-- InsertSequenceFeature plugin


prompt populate null dots.ExonFeature.order_number

update dots.ExonFeature 
set order_number = (select count(*)
                    from dots.ExonFeature ef1, dots.ExonFeature ef2,
                         dots.NaLocation nl1, dots.NaLocation nl2
                    where ef1.order_number is null
                      and ef1.na_feature_id = nl1.na_feature_id
                      and ef2.na_feature_id = nl2.na_feature_id
                      and ef1.parent_id = ef2.parent_id
                      and nl1.start_min >= nl2.start_min
                      and ef1.na_feature_id = ExonFeature.na_feature_id) 
where ExonFeature.order_number is null
  and ExonFeature.na_feature_id in (select na_feature_id
                                    from dots.NaLocation
                                    where is_reversed = 0);

commit;

prompt same thing, reverse strand
update dots.ExonFeature 
set order_number = (select count(*)
                    from dots.ExonFeature ef1, dots.ExonFeature ef2,
                         dots.NaLocation nl1, dots.NaLocation nl2
                    where ef1.order_number is null
                      and ef1.na_feature_id = nl1.na_feature_id
                      and ef2.na_feature_id = nl2.na_feature_id
                      and ef1.parent_id = ef2.parent_id
                      and nl1.start_min <= nl2.start_min
                      and ef1.na_feature_id = ExonFeature.na_feature_id) 
where ExonFeature.order_number is null
  and ExonFeature.na_feature_id in (select na_feature_id
                                    from dots.NaLocation
                                    where is_reversed = 1);

commit;

prompt populate dots.ExonFeature.source_id as <parent-source_id>-<exon-number>

update dots.ExonFeature
set source_id = (select gf.source_id || '-' || ef.order_number
                 from dots.GeneFeature gf, dots.ExonFeature ef
                 where gf.na_feature_id = ef.parent_id
                   and ef.na_feature_id = ExonFeature.na_feature_id);

commit;

prompt move ORFs from dots.Transcript to dots.Miscellaneous

update dots.NaFeature
set subclass_view = 'Miscellaneous'
where subclass_view = 'Transcript'
  and sequence_ontology_id = (select sequence_ontology_id
                              from sres.SequenceOntology
                              where term_name = 'ORF');

commit;

prompt populate dots.Transcript.source_id as "<gene-source_id>-1"

update dots.Transcript t
set source_id = (select source_id || '-1'
                 from dots.GeneFeature gf
                 where gf.na_feature_id = t.parent_id)
where t.parent_id is not null;

commit;

prompt lookup table for first and last exon

create table apidb.EndExons as
select parent_id, min(order_number) as min_order_number,
       max(order_number) as max_order_number
from dots.ExonFeature
group by parent_id;

create index apidb.endexon_ix on apidb.EndExons(parent_id);

prompt fix translation_start for forward strand
-- simply the exon.coding_start - exonloc.start_min + 1

update dots.translatedaafeature taaf
set taaf.translation_start =
(select ef.coding_start - l.start_min + 1
from dots.exonfeature ef, dots.nalocation l,dots.transcript t
where t.na_feature_id = taaf.na_feature_id
and ef.parent_id = t.parent_id
and ef.order_number = (select min_order_number from apidb.EndExons ee
                       where ee.parent_id = t.parent_id)
and l.na_feature_id = ef.na_feature_id)
where taaf.na_feature_id in (
select it.na_feature_id from dots.transcript it, dots.genefeature igf, dots.NALOCATION il
where igf.na_feature_id = il.na_feature_id
and igf.na_feature_id = it.parent_id
and il.is_reversed = 0);

commit;


prompt fix translation_start for reverse strand
-- simply the exonloc.end_max - exon.coding_start + 1

update dots.translatedaafeature taaf
set taaf.translation_start = 
(select l.end_max - ef.coding_start + 1
from dots.exonfeature ef, dots.nalocation l,dots.transcript t
where t.na_feature_id = taaf.na_feature_id
and ef.parent_id = t.parent_id
and ef.order_number = (select min_order_number from apidb.EndExons ee
                       where ee.parent_id = t.parent_id)
and l.na_feature_id = ef.na_feature_id)
where taaf.na_feature_id in (
select it.na_feature_id from dots.transcript it, dots.genefeature igf, dots.NALOCATION il
where igf.na_feature_id = il.na_feature_id
and igf.na_feature_id = it.parent_id
and il.is_reversed = 1);

commit;

prompt fix translation_stop for forward strand
-- need to get the last exon and compute
-- (transcript sequence.length - (exonloc.end_max - exon.coding_end)

update dots.translatedaafeature taaf
set taaf.translation_stop = 
(select snas.length - (l.end_max - ef.coding_end)
from dots.exonfeature ef, dots.nalocation l,dots.transcript t,dots.splicednasequence snas
where t.na_feature_id = taaf.na_feature_id
and snas.na_sequence_id = t.na_sequence_id
and ef.parent_id = t.parent_id
and ef.order_number = (select max_order_number from apidb.EndExons ee
                       where ee.parent_id = t.parent_id)
and l.na_feature_id = ef.na_feature_id)
where taaf.na_feature_id in (
select it.na_feature_id from dots.transcript it, dots.genefeature igf, dots.NALOCATION il
where igf.na_feature_id = il.na_feature_id
and igf.na_feature_id = it.parent_id
and il.is_reversed = 0);

commit;


prompt fix translation_stop for reverse strand
-- need to get the last exon and compute
-- (transcript sequence.length - (exon.coding_end - exonloc.start_min)

update dots.translatedaafeature taaf
set taaf.translation_stop = 
(select snas.length - (ef.coding_end - l.start_min)
from dots.exonfeature ef, dots.nalocation l,dots.transcript t,dots.splicednasequence snas
where t.na_feature_id = taaf.na_feature_id
and snas.na_sequence_id = t.na_sequence_id
and ef.parent_id = t.parent_id
and ef.order_number = (select max_order_number from apidb.EndExons ee
                       where ee.parent_id = t.parent_id)
and l.na_feature_id = ef.na_feature_id)
where taaf.na_feature_id in (
select it.na_feature_id from dots.transcript it, dots.genefeature igf, dots.NALOCATION il
where igf.na_feature_id = il.na_feature_id
and igf.na_feature_id = it.parent_id
and il.is_reversed = 1);

commit;

prompt make protein source_ids same as transcript source_ids
update dots.TranslatedAaSequence tas
set source_id = (select t.source_id
                 from dots.Transcript t, dots.TranslatedAaFeature taf
                 where t.na_feature_id = taf.na_feature_id
                  and taf.aa_sequence_id = tas.aa_sequence_id
                  and t.source_id = tas.source_id);

commit;

prompt make splicednasequence source_ids same as transcript source_ids
update dots.splicednasequence sna 
set source_id = (
select t.source_id 
from dots.transcript t 
where t.na_sequence_Id = sna.na_sequence_id
and sna.source_id is null
);

commit;