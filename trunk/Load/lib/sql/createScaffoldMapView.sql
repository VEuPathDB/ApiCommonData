grant references on dots.NASequence to apidb;
grant references on dots.VirtualSequence to apidb;
grant references on dots.SequencePiece to apidb;
grant references on dots.ExternalNaSequence to apidb;

grant select on dots.VirtualSequence to apidb with grant option;
grant select on dots.SequencePiece to apidb with grant option;
grant select on dots.ExternalNaSequence to apidb with grant option;

CREATE MATERIALIZED VIEW apidb.scaffold_map AS (
     SELECT 
      na_sequence_id as virtual_na_sequence_id, 
      parent_id as virtual_source_id,
      piece_na_sequence_id,
      source_id as piece_source_id,
      (offset + 1) as startm,
      (offset + length) as end,
      strand_orientation,
      length, 
      sequence_order
FROM (
(SELECT vs.na_sequence_id, vs.source_id as parent_id, ens.source_id, 
       sp.piece_na_sequence_id, sp.sequence_order,
       ens.length, vs.length as chr_length, sp.strand_orientation,
       0 as offset
 FROM dots.VirtualSequence vs, dots.SequencePiece sp,
     dots.ExternalNaSequence ens
 WHERE vs.na_sequence_id = sp.virtual_na_sequence_id
  and ens.na_sequence_id = sp.piece_na_sequence_id
  and sp.sequence_order = 1 
GROUP by vs.na_sequence_id, vs.source_id, ens.source_id, sp.piece_na_sequence_id, sp.sequence_order,
       ens.length, vs.length, sp.strand_orientation)
UNION
(SELECT vs.na_sequence_id, vs.source_id as parent_id, ens.source_id, 
       sp.piece_na_sequence_id, sp.sequence_order,
       ens.length, vs.length as chr_length, sp.strand_orientation,
       sum(predecessors.length) as offset
 FROM dots.VirtualSequence vs, dots.SequencePiece sp,
     dots.ExternalNaSequence ens,
     (select sp2.virtual_na_sequence_id, sp2.sequence_order, ens2.length
      from dots.SequencePiece sp2,
           dots.ExternalNaSequence ens2
      where sp2.piece_na_sequence_id = ens2.na_sequence_id) predecessors
 WHERE vs.na_sequence_id = sp.virtual_na_sequence_id
  and ens.na_sequence_id = sp.piece_na_sequence_id
  and vs.na_sequence_id = predecessors.virtual_na_sequence_id(+)
  and sp.sequence_order > predecessors.sequence_order
GROUP by vs.source_id, vs.na_sequence_id, ens.source_id, sp.piece_na_sequence_id, sp.sequence_order,
       ens.length, vs.length, sp.strand_orientation )
ORDER by na_sequence_id, offset, sequence_order)
);


GRANT insert, select, update, delete ON apidb.scaffold_map to gus_w;
GRANT select ON apidb.scaffold_map TO gus_r;


exit;
