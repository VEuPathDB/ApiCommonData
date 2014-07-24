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
    modification_date            date
);

create index apidb.SnpNASeqLoc_idx
on apidb.Snp (location, na_sequence_id);

create sequence apidb.Snp_sq;

grant select on apidb.Snp to gus_r;
grant insert, select, update, delete on apidb.Snp to gus_w;
grant select ON apidb.Snp_sq TO gus_w;

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
    modification_date            date
);

create index apidb.SnpVarNASeqLoc_idx
on apidb.SequenceVariation (ref_na_sequence_id, location);

create sequence apidb.SequenceVariation_sq;

grant select on apidb.SequenceVariation to gus_r;
grant insert, select, update, delete on apidb.SequenceVariation to gus_w;
grant select ON apidb.SequenceVariation_sq TO gus_w;

exit;

