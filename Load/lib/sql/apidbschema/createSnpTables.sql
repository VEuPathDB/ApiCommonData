create table apidb.Snp (
    na_sequence_id               number(10) not null,/* references dots.NaSequenceImp */
    location                     number(10) not null,
    snp_id                       number(12) not null,
    gene_na_feature_id           number(10), /* references dots.NaFeatureImp */
    source_id                    varchar(100) not null,
    reference_strain             varchar(50) not null,
    reference_na                 varchar(1) not null,
    reference_aa                 varchar(1),
    position_in_cds              number(5),
    position_in_protein          number(5),
    external_database_release_id number(10) not null,/* references sres.externaldatabaserelease */
    has_nonsynonymous_allele     number(1),  /* if 1 then at least one allele non-synonymous .. not sure in practice that we use this */
    major_allele                 varchar(1) not null,
    minor_allele                 varchar(10) not null,  /* note there could be  more than one but we are only loading first based on sorted list */
    major_allele_count           number(5) not null,
    minor_allele_count           number(5) not null,
    major_product                varchar(1),
    minor_product                varchar(1),
    distinct_strain_count        number(3), 
    distinct_allele_count        number(3),
    modification_date            date,
    foreign key (gene_na_feature_id) references dots.NaFeatureImp (na_feature_id),
    foreign key (na_sequence_id) references dots.NaSequenceImp (na_sequence_id),
    foreign key (external_database_release_id) references sres.ExternalDatabaseRelease (external_database_release_id),
    primary key (na_sequence_id, location),
    unique (source_id),
    unique (snp_id)
);

grant insert, select, update, delete on apidb.Snp to gus_w;
grant select ON apidb.Snp to gus_r;

create sequence apidb.Snp_sq;
grant select ON apidb.Snp_sq to gus_w;

create index apidb.SnpLocIx
on apidb.Snp (na_sequence_id, location, source_id, snp_id, gene_na_feature_id);

create index apidb.SnpSrcIx
on apidb.Snp (source_id, na_sequence_id, location, snp_id, gene_na_feature_id);

create index apidb.SnpIdIx
on apidb.Snp (snp_id, na_sequence_id, location, source_id, gene_na_feature_id);

--------------------------------------------------------------------------------
create table apidb.SequenceVariation (
    sequence_variation_id        number(12) not null,
    na_sequence_id               number(10) not null,
    location                     number(10) not null,
    strain                       varchar(50) not null,
    allele                       varchar(1) not null,
    matches_reference            number(3) not null,
    product                      varchar(1),
    external_database_release_id number(10) not null,
    snp_ext_db_rls_id            number(10) not null,
    p_value                      float(126),
    read_percent                 float(126),
    coverage                     number(12),
    quality                      number(12),
    ref_na_sequence_id           number(10) not null,
    modification_date            date,
    primary key (sequence_variation_id),
    foreign key (external_database_release_id) references sres.ExternalDatabaseRelease (external_database_release_id),
    foreign key (snp_ext_db_rls_id) references sres.ExternalDatabaseRelease (external_database_release_id),
    foreign key (na_sequence_id, location) references apidb.Snp (na_sequence_id, location)
);

grant insert, select, update, delete ON apidb.SequenceVariation to gus_w;
grant select ON apidb.SequenceVariation to gus_r;

create sequence apidb.SequenceVariation_sq;
grant select ON apidb.SequenceVariation_sq to gus_w;

create index apidb.SeqVarLocIx
on apidb.SequenceVariation (na_sequence_id, location, strain, allele, sequence_variation_id);

create index apidb.SeqVarStrnIx
on apidb.SequenceVariation (strain, na_sequence_id, location, allele, sequence_variation_id);

create index apidb.SeqVarIdIx
on apidb.SequenceVariation (sequence_variation_id, strain, na_sequence_id, location, allele);

exit
