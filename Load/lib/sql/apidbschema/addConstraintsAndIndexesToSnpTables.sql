WHENEVER SQLERROR EXIT 1;

grant insert, select, update, delete on apidb.Snp to gus_w;
grant select ON apidb.Snp to gus_r;

grant select ON apidb.Snp_sq to gus_w;

alter table apidb.snp add foreign key (gene_na_feature_id) references dots.NaFeatureImp (na_feature_id);
alter table apidb.snp add foreign key (na_sequence_id) references dots.NaSequenceImp (na_sequence_id);
alter table apidb.snp add foreign key (external_database_release_id) references sres.ExternalDatabaseRelease (external_database_release_id);

alter table apidb.snp add unique (source_id);
alter table apidb.snp add unique (snp_id);

alter table apidb.snp add primary key (na_sequence_id, location);

create index apidb.SnpLocIx
on apidb.Snp (na_sequence_id, location, source_id, snp_id, gene_na_feature_id);

create index apidb.SnpSrcIx
on apidb.Snp (source_id, na_sequence_id, location, snp_id, gene_na_feature_id);

create index apidb.SnpIdIx
on apidb.Snp (snp_id, na_sequence_id, location, source_id, gene_na_feature_id);
----------------------------------------------------------------

grant insert, select, update, delete ON apidb.SequenceVariation to gus_w;
grant select ON apidb.SequenceVariation to gus_r;


grant select ON apidb.SequenceVariation_sq to gus_w;

alter table apidb.sequencevariation add primary key (sequence_variation_id);
alter table apidb.sequencevariation add foreign key (external_database_release_id) references sres.ExternalDatabaseRelease (external_database_release_id);
alter table apidb.sequencevariation add foreign key (snp_ext_db_rls_id) references sres.ExternalDatabaseRelease (external_database_release_id);
alter table apidb.sequencevariation add foreign key (ref_na_sequence_id, location) references apidb.Snp (na_sequence_id, location);

create index apidb.SeqVarLocIx
on apidb.SequenceVariation (na_sequence_id, location, strain, allele, sequence_variation_id);

create index apidb.SeqVarStrnIx
on apidb.SequenceVariation (strain, na_sequence_id, location, allele, sequence_variation_id);

create index apidb.SeqVarIdIx
on apidb.SequenceVariation (sequence_variation_id, strain, na_sequence_id, location, allele);

exit;
