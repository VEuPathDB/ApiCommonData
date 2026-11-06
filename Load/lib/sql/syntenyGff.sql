-- Read-only. Emits GFF3 body lines for one reference organism's synteny.
--
-- Run by Load/bin/makeSyntenyGff.pl, which binds the reference organism to the
-- single placeholder and assembles column 9 from the `attrs` array.
--
-- `attrs` is a flat JSON array of key, value, key, value. An array and not an
-- object because the reader is Perl, whose hashes are unordered, so an object
-- would scramble attribute order between runs. Values travel unescaped -- JSON
-- carries any string safely -- and the script percent-encodes them on the way
-- out, which is why this issues nothing but a SELECT.
--
-- Two feature types per syntenic organism, both in REFERENCE coordinates:
--   * one `syntenic_region` per apidb.synteny span
--   * one `gene` per apidb.syntenicgene
--
-- Coordinates come straight from the stored projection. apidb.syntenicgene's
-- (start_min, end_max) is ALREADY reference space -- InsertSyntenySpans.pm
-- computed it per gene pair at load time -- so there is nothing to scale here.
-- The JBrowse1 feature API re-derived positions by linearly stretching the
-- VISIBLE genes' bounding box, which a static file cannot reproduce and does
-- not need to; the client repositions them per window instead.
--
-- The bound parameter is the reference organism abbreviation. Every sequence it
-- owns becomes a row of the GFF, and every genome syntenic to it becomes a lane.


-- The reference organism, bound once. Every other reference to it reads this,
-- so the statement takes a single placeholder however many places need it.
with params as (
  select cast(? as text) as refabbrev
),
org_names as (
  -- one row per organism. The table is partitioned by project, so an organism
  -- present in two projects would otherwise duplicate every row joined to it.
  select org_abbrev, min(organism) as organism
  from webready.organismselecttaxonrank_p
  group by org_abbrev
),
ref_seq as (
  -- keyed on the organism, not on an id range: sequence ids are contiguous for
  -- some genomes and scattered for others, so a range is a property of the
  -- genome that happens to be first rather than a parameter
  select g.na_sequence_id, g.source_id, g.length
  from webready.genomicseqattributes_p g, params p
  where g.org_abbrev = p.refabbrev
),
-- One row per (span, organism). A span's syn_organism_abbrev lives on its
-- genes, not on the span, so it is read back from them.
-- The span's extent is the synteny row's own `a_start`/`a_end`, which is what
-- mercator aligned. Deriving it from the min/max of the genes inside it gives a
-- shorter bar that stops at the first and last gene, which is a different fact.
spans as (
  select sg.synteny_id,
         sg.na_sequence_id,
         sg.syn_organism_abbrev,
         min(sy.a_start)   as ref_start,
         max(sy.a_end)     as ref_end,
         count(*)          as gene_count
  from apidb.syntenicgene sg
  join apidb.synteny sy on sy.synteny_id = sg.synteny_id
  where sg.na_sequence_id in (select na_sequence_id from ref_seq)
  group by sg.synteny_id, sg.na_sequence_id, sg.syn_organism_abbrev
),
span_rows as (
  select rs.source_id                                   as seqid,
         'syntenic_region'                              as type,
         s.ref_start                                    as fstart,
         s.ref_end                                      as fend,
         '.'                                            as strand,
         'span_' || s.synteny_id || '_' || s.syn_organism_abbrev as fid,
         -- a lane of its own: a span bar and the genes inside it answer
         -- different questions, and packing them together puts the bar on one
         -- row of the same section rather than beside it
         s.syn_organism_abbrev || ' span'               as subtrack,
         json_build_array(
           'ID', 'span_' || s.synteny_id || '_' || s.syn_organism_abbrev,
           'Name', coalesce(oa.organism, ''),
           'subtrack', s.syn_organism_abbrev || ' span',
           'synType', 'span',
           'syntenyId', s.synteny_id,
           'geneCount', s.gene_count,
           'organism', coalesce(oa.organism, ''),
           'isReversed', coalesce(sy.is_reversed, 0)
         )                                              as attrs
  from spans s
  join ref_seq rs                      on rs.na_sequence_id = s.na_sequence_id
  join apidb.synteny sy                on sy.synteny_id     = s.synteny_id
  left join org_names oa               on oa.org_abbrev     = s.syn_organism_abbrev
),
gene_rows as (
  select rs.source_id                                   as seqid,
         'gene'                                         as type,
         sg.start_min                                   as fstart,
         sg.end_max                                     as fend,
         case when sg.is_reversed = 1 then '-' else '+' end as strand,
         'syngene_' || sg.syntenic_gene_id              as fid,
         sg.syn_organism_abbrev                         as subtrack,
         json_build_array(
           'ID', 'syngene_' || sg.syntenic_gene_id,
           'Name', coalesce(ga.source_id, ''),
           'subtrack', sg.syn_organism_abbrev,
           'synType', 'gene',
           'syntenyId', sg.synteny_id,
           'geneId', coalesce(ga.source_id, ''),
           'organism', coalesce(ga.organism, ''),
           'product', coalesce(ga.product, ''),
           'soTerm', coalesce(ga.so_term_name, ''),
           'isPseudo', coalesce(ga.is_pseudo, 0),
           'isDeprecated', coalesce(ga.is_deprecated, 0),
           -- native coordinates, so a detail panel can link out to the gene
           -- on its own genome rather than only showing where it projects
           'nativeSequence', coalesce(ga.sequence_id, ''),
           'nativeStart', ga.start_min,
           'nativeEnd', ga.end_max,
           -- the span's orientation, carried on every gene because a
           -- viewport-time rescale needs it to pick the forward or reverse
           -- branch and cannot go back to the span feature to ask
           'spanIsReversed', coalesce(sy.is_reversed, 0),
           -- JBrowse1's `geneGroupAttributeName`: genes sharing this are
           -- orthologs, which is what ortholog shading draws between lanes
           'orthologGroup', coalesce(og.group_id, ''),
           'paralogCount', coalesce(og.gene_paralog_number, 0)
         )                                              as attrs
  from apidb.syntenicgene sg
  join ref_seq rs                      on rs.na_sequence_id = sg.na_sequence_id
  join webready.geneattributes_p ga   on ga.na_feature_id  = sg.syn_na_feature_id
  join apidb.synteny sy                on sy.synteny_id     = sg.synteny_id
  left join webready.geneorthologgroup og on og.gene_id     = ga.source_id
  where sg.na_sequence_id in (select na_sequence_id from ref_seq)
),
-- The parts of each syntenic gene, so a gene draws as a gene glyph rather than
-- a box. Positions here are the gene's own, unscaled: the client rescales a
-- gene and its parts together, through one transform per span, which is what
-- keeps an exon inside the gene it belongs to.
syn_genes as (
  select sg.syntenic_gene_id,
         sg.syn_na_feature_id,
         sg.na_sequence_id,
         sg.syn_organism_abbrev,
         sg.is_reversed,
         sg.synteny_id,
         ga.so_term_name,
         -- the gene's own affine frame: where it sits in reference space, and
         -- the native interval that maps onto it
         sg.start_min    as ref_start,
         sg.end_max      as ref_end,
         ga.start_min    as nat_start,
         greatest(ga.end_max - ga.start_min, 1) as nat_span,
         greatest(sg.end_max - sg.start_min, 0) as ref_span,
         sy.is_reversed  as span_reversed
  from apidb.syntenicgene sg
  join webready.geneattributes_p ga
    on ga.na_feature_id = sg.syn_na_feature_id
   and ga.org_abbrev    = sg.syn_organism_abbrev
  join apidb.synteny sy on sy.synteny_id = sg.synteny_id
  where sg.na_sequence_id in (select na_sequence_id from ref_seq)
),
-- A part's position in reference space, by the gene's own frame. The GFF needs
-- one because tabix indexes on it and a child indexed at its native coordinate
-- would be fetched nowhere near its parent. The client then rescales gene and
-- parts together, so this is a starting position rather than the final one.

-- Transcripts are direct children of the gene; CDS and UTRs hang off the
-- transcript, so they are reached through it rather than through the gene.
transcript_rows as (
  select rs.source_id                                   as seqid,
         case when g.so_term_name in ('protein_coding_gene',
                                      'transposable_element_gene')
              then 'mRNA' else 'transcript' end         as type,
         case when g.span_reversed = 1
              then round(g.ref_end - ((fl.end_max   - g.nat_start)::numeric / g.nat_span) * g.ref_span)
              else round(g.ref_start + ((fl.start_min - g.nat_start)::numeric / g.nat_span) * g.ref_span)
         end                                            as fstart,
         case when g.span_reversed = 1
              then round(g.ref_end - ((fl.start_min - g.nat_start)::numeric / g.nat_span) * g.ref_span)
              else round(g.ref_start + ((fl.end_max   - g.nat_start)::numeric / g.nat_span) * g.ref_span)
         end                                            as fend,
         case when g.is_reversed = 1 then '-' else '+' end as strand,
         'syntx_' || g.syntenic_gene_id || '_' || fl.na_feature_id as fid,
         g.syn_organism_abbrev                          as subtrack,
         json_build_array(
           'ID', 'syntx_' || g.syntenic_gene_id || '_' || fl.na_feature_id,
           'Parent', 'syngene_' || g.syntenic_gene_id,
           'subtrack', g.syn_organism_abbrev,
           'synType', 'transcript',
           'syntenyId', g.synteny_id,
           'nativeStart', fl.start_min,
           'nativeEnd', fl.end_max,
           'spanIsReversed', coalesce(g.span_reversed, 0)
         )                                              as attrs
  from syn_genes g
  join ref_seq rs           on rs.na_sequence_id = g.na_sequence_id
  join apidb.featurelocation fl
    on fl.parent_id    = g.syn_na_feature_id
   and fl.feature_type = 'Transcript'
),
part_rows as (
  select rs.source_id                                   as seqid,
         fl.feature_type                                as type,
         case when g.span_reversed = 1
              then round(g.ref_end - ((fl.end_max   - g.nat_start)::numeric / g.nat_span) * g.ref_span)
              else round(g.ref_start + ((fl.start_min - g.nat_start)::numeric / g.nat_span) * g.ref_span)
         end                                            as fstart,
         case when g.span_reversed = 1
              then round(g.ref_end - ((fl.start_min - g.nat_start)::numeric / g.nat_span) * g.ref_span)
              else round(g.ref_start + ((fl.end_max   - g.nat_start)::numeric / g.nat_span) * g.ref_span)
         end                                            as fend,
         case when g.is_reversed = 1 then '-' else '+' end as strand,
         'synpart_' || g.syntenic_gene_id || '_' || fl.na_feature_id as fid,
         g.syn_organism_abbrev                          as subtrack,
         json_build_array(
           'ID', 'synpart_' || g.syntenic_gene_id || '_' || fl.na_feature_id,
           'Parent', 'syntx_' || g.syntenic_gene_id || '_' || ta.na_feature_id,
           'subtrack', g.syn_organism_abbrev,
           'synType', fl.feature_type,
           'syntenyId', g.synteny_id,
           'nativeStart', fl.start_min,
           'nativeEnd', fl.end_max,
           'spanIsReversed', coalesce(g.span_reversed, 0)
         )                                              as attrs
  from syn_genes g
  join ref_seq rs           on rs.na_sequence_id = g.na_sequence_id
  join webready.transcriptattributes_p ta
    on ta.gene_na_feature_id = g.syn_na_feature_id
  join apidb.featurelocation fl
    on fl.parent_id    = ta.na_feature_id
   and fl.feature_type in ('CDS', 'five_prime_UTR', 'three_prime_UTR')
),
-- The reference organism as a lane of its own. Production shows it, and it is
-- what the other lanes are positioned against -- without it the shading joins
-- comparisons to each other and never to the thing being compared to.
--
-- These features carry no `syntenyId`, so the client leaves them where they
-- are: they ARE reference coordinates and rescaling them would be circular.
ref_gene_rows as (
  select rs.source_id                                   as seqid,
         'gene'                                         as type,
         ga.start_min                                   as fstart,
         ga.end_max                                     as fend,
         case when ga.is_reversed = 1 then '-' else '+' end as strand,
         'refgene_' || ga.na_feature_id                 as fid,
         p.refabbrev                                   as subtrack,
         json_build_array(
           'ID', 'refgene_' || ga.na_feature_id,
           'Name', coalesce(ga.source_id, ''),
           'subtrack', p.refabbrev,
           'synType', 'reference',
           'geneId', coalesce(ga.source_id, ''),
           'organism', coalesce(ga.organism, ''),
           'product', coalesce(ga.product, ''),
           'soTerm', coalesce(ga.so_term_name, ''),
           'isPseudo', coalesce(ga.is_pseudo, 0),
           'orthologGroup', coalesce(og.group_id, ''),
           'paralogCount', coalesce(og.gene_paralog_number, 0)
         )                                              as attrs
  from params p,
       webready.geneattributes_p ga
  join ref_seq rs on rs.na_sequence_id = ga.na_sequence_id
  left join webready.geneorthologgroup og on og.gene_id = ga.source_id
  where ga.na_sequence_id in (select na_sequence_id from ref_seq)
),
ref_transcript_rows as (
  select rs.source_id                                   as seqid,
         case when ga.so_term_name in ('protein_coding_gene',
                                       'transposable_element_gene')
              then 'mRNA' else 'transcript' end         as type,
         fl.start_min                                   as fstart,
         fl.end_max                                     as fend,
         case when ga.is_reversed = 1 then '-' else '+' end as strand,
         'reftx_' || fl.na_feature_id                   as fid,
         p.refabbrev                                   as subtrack,
         json_build_array(
           'ID', 'reftx_' || fl.na_feature_id,
           'Parent', 'refgene_' || ga.na_feature_id,
           'subtrack', p.refabbrev,
           'synType', 'reference'
         )                                              as attrs
  from params p,
       webready.geneattributes_p ga
  join ref_seq rs on rs.na_sequence_id = ga.na_sequence_id
  join apidb.featurelocation fl
    on fl.parent_id    = ga.na_feature_id
   and fl.feature_type = 'Transcript'
  where ga.na_sequence_id in (select na_sequence_id from ref_seq)
),
ref_part_rows as (
  select rs.source_id                                   as seqid,
         fl.feature_type                                as type,
         fl.start_min                                   as fstart,
         fl.end_max                                     as fend,
         case when ga.is_reversed = 1 then '-' else '+' end as strand,
         'refpart_' || fl.na_feature_id                 as fid,
         p.refabbrev                                   as subtrack,
         json_build_array(
           'ID', 'refpart_' || fl.na_feature_id,
           'Parent', 'reftx_' || ta.na_feature_id,
           'subtrack', p.refabbrev,
           'synType', 'reference'
         )                                              as attrs
  from params p,
       webready.geneattributes_p ga
  join ref_seq rs on rs.na_sequence_id = ga.na_sequence_id
  join webready.transcriptattributes_p ta
    on ta.gene_na_feature_id = ga.na_feature_id
  join apidb.featurelocation fl
    on fl.parent_id    = ta.na_feature_id
   and fl.feature_type in ('CDS', 'five_prime_UTR', 'three_prime_UTR')
  where ga.na_sequence_id in (select na_sequence_id from ref_seq)
),
-- The reference's own span lane: the sequence itself, end to end. It carries no
-- alignment, which is the point -- it is the ruler the other spans are measured
-- against, and its absence left the reference the one lane with a gap where
-- every other organism has a bar.
ref_span_rows as (
  select rs.source_id                                   as seqid,
         'syntenic_region'                              as type,
         1                                              as fstart,
         rs.length                                      as fend,
         '.'                                            as strand,
         'refseq_' || rs.na_sequence_id                 as fid,
         p.refabbrev || ' span'                        as subtrack,
         json_build_array(
           'ID', 'refseq_' || rs.na_sequence_id,
           'Name', coalesce(rs.source_id, ''),
           'subtrack', p.refabbrev || ' span',
           'synType', 'span',
           'sequenceLength', rs.length
         )                                              as attrs
  from params p,
       ref_seq rs
)
select seqid, type, fstart, fend, strand, attrs
from (
  select * from span_rows
  union all select * from gene_rows
  union all select * from transcript_rows
  union all select * from part_rows
  union all select * from ref_gene_rows
  union all select * from ref_transcript_rows
  union all select * from ref_part_rows
  union all select * from ref_span_rows
) t
order by seqid, fstart, fend;
