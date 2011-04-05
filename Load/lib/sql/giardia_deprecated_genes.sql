/* note, must be run as user apidb */

drop table overlapping_genes;

create table overlapping_genes as
select distinct case when l.is_reversed = li.is_reversed then 'same' else 'opposite' end as orientation,
case when l.is_reversed = li.is_reversed then 'head to tail' when l.is_reversed = 0 then 'head to head' else 'tail to tail' end as spec_orientation,
gf.source_id as left_id, l.end_max - l.start_min as left_length,gf.product as left_product,
gfi.source_id as right_id,li.end_max - li.start_min as right_length, gfi.product as right_product, l.end_max - li.start_min as overlap,
round(((l.end_max - li.start_min) / least((li.end_max - li.start_min),(l.end_max - l.start_min)) * 100),2) as percentage
from dots.GENEFEATURE gf, dots.GENEFEATURE gfi,dots.NALOCATION l, dots.NALOCATION li
where gf.na_feature_id != gfi.na_feature_id
and gf.source_id like 'GL%'
and gfi.source_id like 'GL%'
and gf.na_feature_id = l.na_feature_id
and gfi.na_feature_id = li.na_feature_id
and gf.na_sequence_id = gfi.na_sequence_id
and li.start_min > l.start_min
and li.start_min < l.end_max
and li.end_max > l.end_max
order by percentage desc;

insert into overlapping_genes (
select distinct case when l.is_reversed = li.is_reversed then 'same' else 'opposite' end as orientation,
'subsumed' as spec_orientation,
gf.source_id as left_id, l.end_max - l.start_min as left_length,gf.product as left_product,
gfi.source_id as right_id,li.end_max - li.start_min as right_length, gfi.product as right_product, li.end_max - li.start_min as overlap,
100 as percentage
from dots.GENEFEATURE gf, dots.GENEFEATURE gfi,dots.NALOCATION l, dots.NALOCATION li
where gf.na_feature_id != gfi.na_feature_id
and gf.source_id like 'GL%'
and gfi.source_id like 'GL%'
and gf.na_feature_id = l.na_feature_id
and gfi.na_feature_id = li.na_feature_id
and gf.na_sequence_id = gfi.na_sequence_id
and li.start_min >= l.start_min
and li.start_min <= l.end_max
and li.end_max <= l.end_max);

/*
select spec_orientation,count(*) from overlapping_genes
group by spec_orientation;

select * from overlapping_genes;

select left_length,orientation,round((right_length / left_length) * 100,2) as perc from overlapping_genes where spec_orientation = 'subsumed'
and left_product != 'Hypothetical protein'
and right_product != 'Hypothetical protein'
order by perc desc;
*/

/* subsumed genes */

drop table DeprecatedGenes;

create table DeprecatedGenes as
select distinct right_id as source_id, 'subsumed .. no annotation' as comm
from overlapping_genes
where left_product != 'Hypothetical protein'
and right_product = 'Hypothetical protein'
and spec_orientation = 'subsumed';

insert into DeprecatedGenes (
select distinct left_id as source_id, 'subsumed .. no annotation' as comm
from overlapping_genes
where right_product != 'Hypothetical protein'
and left_product = 'Hypothetical protein'
and spec_orientation = 'subsumed');

insert into DeprecatedGenes (
select case when right_length > left_length then left_id else right_id end as source_id, 'shorter hypothetical' as comm
from overlapping_genes
where right_product = 'Hypothetical protein'
and left_product = 'Hypothetical protein'
and spec_orientation = 'subsumed');

select count(*) from (select source_id,count(*) from DeprecatedGenes
group by source_id
having count(*) > 1);

/* select * from DeprecatedGenes; */

/* special cases from HIlary re subsumed genes */
insert into DeprecatedGenes (
select 'GL50803_37434','special case' from dual);

insert into DeprecatedGenes (
select 'GL50803_38134','special case' from dual);

insert into DeprecatedGenes (
select 'GL50803_35985','special case' from dual);

delete from DeprecatedGenes where source_id in ('GL50803_112080','GL50803_104186');

/* overlapping genes */

/* keep overlaps involving tRNA or rRNA */

/* both hypotheticals and  one < 100 aa ( 300 nt)*/
insert into DeprecatedGenes (
select case when right_length > left_length then left_id else right_id end as source_id, 'shorter ol hypothetical' as comm
from overlapping_genes
where spec_orientation != 'subsumed'
and right_product = 'Hypothetical protein'
and left_product = 'Hypothetical protein'
and least(left_length,right_length) < 300);

/* rest where both hypothetical */
insert into DeprecatedGenes (
select case when right_length > left_length then left_id else right_id end as source_id, 'shorter ol hypothetical' as comm
from overlapping_genes
where spec_orientation != 'subsumed'
and right_product = 'Hypothetical protein'
and left_product = 'Hypothetical protein'
and least(left_length,right_length) >= 300
and (overlap > 100 or percentage > 25));



/* overlapping one annotated */
insert into DeprecatedGenes (
select distinct right_id as source_id, 'overlap .. no annotation' as comm
from overlapping_genes
where left_product != 'Hypothetical protein'
and right_product = 'Hypothetical protein'
and spec_orientation != 'subsumed'
and overlap > 100 
and percentage > 25);

insert into DeprecatedGenes (
select distinct left_id as source_id, 'overlap .. no annotation' as comm
from overlapping_genes
where right_product != 'Hypothetical protein'
and left_product = 'Hypothetical protein'
and spec_orientation != 'subsumed'
and overlap > 100 
and percentage > 25);

/* overlapping genes both annotated */
/* tail to tail */
insert into DeprecatedGenes (
select case when right_length > left_length then left_id else right_id end as source_id, 'shorter ol hypothetical' as comm
from overlapping_genes
where spec_orientation = 'tail to tail'
and right_product != 'Hypothetical protein'
and left_product != 'Hypothetical protein'
and (overlap > 100 or percentage > 25));

/* head to tail */
insert into DeprecatedGenes (
select case when right_length > left_length then left_id else right_id end as source_id, 'shorter ol hypothetical' as comm
from overlapping_genes
where spec_orientation in ('head to tail','head to head')
and right_product != 'Hypothetical protein'
and left_product != 'Hypothetical protein'
and overlap > 100 
and percentage > 25);

/* now remove the ones that overlap with tRNA or rRNA */
delete from DeprecatedGenes where source_id in (
select og.right_id
from overlapping_genes og, apidb.geneattributes ga
where og.left_id = ga.source_id
and ga.so_term_name in ('tRNA_encoding','rRNA_encoding')
and og.spec_orientation != 'subsumed');

delete from DeprecatedGenes where source_id in (
select og.left_id
from overlapping_genes og, apidb.geneattributes ga
where og.right_id = ga.source_id
and ga.so_term_name in ('tRNA_encoding','rRNA_encoding')
and og.spec_orientation != 'subsumed');

/* manually review all deprecated that are not hypotheticals and remove if necessary */
delete from DeprecatedGenes 
where source_id in ('GL50803_86440','GL50803_5919','GL50803_16180','GL50803_16463','GL50803_31576','GL50803_86440','GL50803_112080','GL50803_104186');

delete from DeprecatedGenes 
where source_id in ('GL50803_103365','GL50803_16773','GL50803_16641','GL50803_22629','GL50803_25080','GL50803_13783');

/* genes that have massspec evidence .. reviewed by Hilary */
delete from DeprecatedGenes 
where source_id in ('GL50803_16969','GL50803_7843','GL50803_16773','GL50803_22629','GL50803_16234','GL50803_39483');

commit;

grant select on DeprecatedGenes to gus_r;

/*
drop table distinct_DeprecatedGenes;

create table distinct_DeprecatedGenes as
select distinct source_id from DeprecatedGenes;

grant select on distinct_DeprecatedGenes to gus_r;
*/


/* rules from Hilary Morrison 
Subsumed Genes:

1) One annotated, one hypothetical: keep annotated gene.
	In all but 30 cases, the annotated gene is the longer of the pair.
	Exceptions include tRNAs, ribosomal proteins.
2) Both hypothetical: keep longer of pair.

Exceptions that should be examined (these are rare in Subsumed Genes set):

Any case where both are annotated: how good is annotation?
	GL50803_27446494, Calmodulin antisense orf and GL50803_5333, Calmodulin overlap: retain both (Fran Gillin)
	GL50803_303542129, Kinase, NEK and GL50803_35985, HCP (Adrian Hehl; Fran Gillin)
	GL50803_6835, Brix domain containing protein and GL50803_37434, ditto: weak evidence, retain longer
	GL50803_11992, TCP-1 cpn and GL50803_38134, Thermosome beta: weak evidence for thermosome beta; retain TCP-1.

Hypothetical proteins longer than 400 aas
	GL50803_112080 is overlapped by alpha tubulin, but has SAGE evidence, TMM, and signal peptide: should retain both.
	GL50803_104186 is overlapped by very small annotated protein: should retain both.

-------------------------------------------------------
Overlapping Genes:

*Overlap by tRNAs or rRNAs should not be considered--keep all these and any overlapping proteins (11 cases).*

Exclude all overlapping genes that are both hypothetical proteins and shorter than 100 aas

Remainder should be considered according to different criteria depending on the annotation, topology of the overlap, and length of gene to be removed

Genes that are flagged for removal but larger than 300 aas should be examined before final decision

1) Same orientation

a) both genes hypothetical proteins: keep longer of the pair if either percentage overlap is greater than 25 or overlap length is greater than 99.  If the percentage overlap is less than 25 and overlap length is less than or equal to 99, keep both (this eliminates 106 of 170 in this group; 12 of these have signal peptides).

b) one gene hypothetical protein: keep the annotated protein.  If the percentage overlap is less than 25 and overlap length is less than or equal to 99, keep both (this eliminates 66 of 119 in this group; 7 of these have signal peptides).

c) both annotated: keep both UNLESS percentage > 25 AND overlap length > 99 (eliminates 7 of 34 in this group; the 7 are likely to be frame shift errors).

2) opposite orientation, overlap is at end of proteins (stop codon)

a) both genes hypothetical proteins: keep longer of the pair if either percentage overlap is greater than 25 or overlap length is greater than 99.  Keep both otherwise (eliminates 96 of 147; 9 have signal peptides)

b) one gene hypothetical protein: keep the annotated protein.  If the percentage overlap is less than 25 and overlap length is less than or equal to 99, keep both (this eliminates 149 of 220 cases in this group; 17 of these have signal peptides vs. 5/71 in genes that were retained.).

c) both annotated: keep longer of the pair if either percentage overlap is greater than 25 or overlap length is greater than 99.  Keep both otherwise.  *There is only one example where an annotated protein is flagged for deletion based on these criteria*.

3) opposite orientation, overlap is a start of proteins (start codon)

a) both genes hypothetical proteins:  If percent > 25 AND overlap > 99, keep longer only.  Otherwise, keep both (eliminates 102/162 cases; many others would be caught by 100aa rule)

b) one gene hypothetical protein: If percent > 25 AND overlap > 99, keep annotated only.  Otherwise, keep both (136 of 225)

c) both annotated: keep both.
*/
