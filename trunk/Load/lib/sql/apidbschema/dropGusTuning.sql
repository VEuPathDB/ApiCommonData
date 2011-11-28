drop index dots.AaSeq_source_ix;
drop index dots.NaFeat_alleles_ix;
drop index dots.AaSequenceImp_string2_ix;
drop index dots.nasequenceimp_string1_seq_ix;
drop index dots.nasequenceimp_string1_ix;
drop index dots.ExonOrder_ix;
drop index dots.SeqvarStrain_ix;
DROP INDEX dots.aasequenceimp_ind_desc;
DROP INDEX sres.dbref_ind_id2;
DROP INDEX sres.dbref_ind_rmk;

ALTER TABLE core.algorithmimplementation
DROP CONSTRAINT alg_imp_uniq;

alter table dots.sequencePiece DROP ( start_position, end_position );

exit
