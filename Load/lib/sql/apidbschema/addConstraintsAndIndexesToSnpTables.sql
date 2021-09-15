
-- these may already be set.  If so, they will print error but not fail
alter table apidb.snp add primary key (snp_id);
alter table apidb.sequencevariation add primary key (sequence_variation_id);

WHENEVER SQLERROR EXIT 1;

grant insert, select, update, delete on apidb.Snp to gus_w;
grant select ON apidb.Snp to gus_r;

grant select ON apidb.Snp_sq to gus_w;

alter table apidb.snp add foreign key (gene_na_feature_id) references dots.NaFeatureImp (na_feature_id);
alter table apidb.snp add foreign key (na_sequence_id) references dots.NaSequenceImp (na_sequence_id);
alter table apidb.snp add foreign key (external_database_release_id) references sres.ExternalDatabaseRelease (external_database_release_id);

alter table apidb.snp add unique (source_id);

alter table apidb.snp add unique (na_sequence_id, location);

create index apidb.SnpLocIx
on apidb.Snp (na_sequence_id, location, source_id, snp_id, gene_na_feature_id) tablespace indx;

create index apidb.SnpSrcIx
on apidb.Snp (source_id, na_sequence_id, location, snp_id, gene_na_feature_id) tablespace indx;

create index apidb.SnpIdIx
on apidb.Snp (snp_id, na_sequence_id, location, source_id, gene_na_feature_id) tablespace indx;

create index apidb.SnpNASeqLocIx 
on apidb.Snp (location, na_sequence_id) tablespace indx;

create index apidb.SnpFeatIx
on apidb.Snp (gene_na_feature_id, snp_id, na_sequence_id, location, source_id) tablespace indx;

create index apidb.Snp_revfk_ix
on apidb.Snp (external_database_release_id, na_sequence_id, location)
tablespace indx;
----------------------------------------------------------------

grant insert, select, update, delete ON apidb.SequenceVariation to gus_w;
grant select ON apidb.SequenceVariation to gus_r;


grant select ON apidb.SequenceVariation_sq to gus_w;


alter table apidb.sequencevariation add foreign key (external_database_release_id) references sres.ExternalDatabaseRelease (external_database_release_id);
alter table apidb.sequencevariation add foreign key (snp_ext_db_rls_id) references sres.ExternalDatabaseRelease (external_database_release_id);
alter table apidb.sequencevariation add foreign key (ref_na_sequence_id, location) references apidb.Snp (na_sequence_id, location);
ALTER TABLE apidb.sequencevariation add FOREIGN KEY (protocol_app_node_id) REFERENCES study.protocolappnode (protocol_app_node_id);
alter table apidb.sequencevariation add foreign key (na_sequence_id) references dots.NaSequenceImp (na_sequence_id);

create index apidb.SeqVarLocIx
on apidb.SequenceVariation (na_sequence_id, location, strain, allele, sequence_variation_id) tablespace indx;

create index apidb.SeqVarStrnIx
on apidb.SequenceVariation (strain, na_sequence_id, location, allele, sequence_variation_id) tablespace indx;

create index apidb.SeqVarIdIx
on apidb.SequenceVariation (sequence_variation_id, strain, na_sequence_id, location, allele) tablespace indx;

create index apidb.SnpVarNASeqLocIx 
on apidb.SequenceVariation (ref_na_sequence_id, location) tablespace indx;

create index apidb.SeqVarRevFkIx1
on apidb.SequenceVariation (external_database_release_id, sequence_variation_id)
tablespace indx;

create index apidb.SeqVarRevFkIx3
on apidb.SequenceVariation (protocol_app_node_id, sequence_variation_id)
tablespace indx;

create index apidb.SeqVarRevFkIx2
on apidb.SequenceVariation (snp_ext_db_rls_id, sequence_variation_id)
tablespace indx;

create index apidb.SeqDateIx
on apidb.SequenceVariation (modification_date, sequence_variation_id)
tablespace indx;

exit;
