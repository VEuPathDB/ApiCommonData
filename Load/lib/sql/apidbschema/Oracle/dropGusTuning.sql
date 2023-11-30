drop index dots.AaSeq_source_ix;
drop index dots.AaSequenceImp_string2_ix;
drop index dots.nasequenceimp_string1_seq_ix;
drop index dots.nasequenceimp_string1_ix;
drop index dots.nf_submod_ix;
drop index dots.af_submod_ix;
drop index dots.ns_submod_ix;
drop index dots.as_submod_ix;
drop index dots.aal_mod_ix;
drop index dots.asmseq_mod_ix;
drop index dots.ba_mod_ix;
drop index dots.drnf_mod_ix;
drop index dots.draf_mod_ix;
drop index dots.est_mod_ix;
drop index dots.gi_mod_ix;
drop index dots.ga_mod_ix;
drop index dots.gai_mod_ix;
drop index dots.gaec_mod_ix;
drop index dots.nfc_mod_ix;
drop index dots.nfng_mod_ix;
drop index dots.ng_mod_ix;
drop index dots.nal_mod_ix;
drop index dots.sp_mod_ix;
drop index dots.ssg_mod_ix;
drop index dots.sim_mod_ix;
drop index dots.simspan_mod_ix;
drop index sres.dbref_mod_ix;
drop index sres.tx_mod_ix;
drop index sres.txname_mod_ix;
drop index lwrFullId_ix;
drop index lwrSrcId_ix;
drop index lwrRefPrim_ix;
drop index lwrRefSec_ix;
drop index SnpStrain_ix;
drop index SnpDiff_ix;



ALTER TABLE core.algorithmimplementation
DROP CONSTRAINT alg_imp_uniq;

alter table dots.NaSequenceImp
drop constraint source_id_uniq;

exec dbms_stats.drop_extended_stats('DOTS', 'NAFEATUREIMP', '(SUBCLASS_VIEW, EXTERNAL_DATABASE_RELEASE_ID)');

exit;
