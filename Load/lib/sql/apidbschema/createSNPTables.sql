create table apidb.SNP (
    gene_na_feature_id        number(10), /* references dots.NaFeatureImp */
    source_id            varchar(100) not null,
    na_sequence_id        number(10) not null,/* references dots.NaSequenceImp */
    location            number(10) not null,
    reference_strain        varchar(50) not null,
    reference_na            varchar(1) not null,
    reference_aa            varchar(1),
    position_in_cds        number(5),
    position_in_protein        number(5),
    external_database_release_id    number(10) not null,/* references sres.externaldatabaserelease */
    has_nonsynonymous_allele    number(1),  /* if 1 then at least one allele non-synonymous .. not sure in practice that we use this */
    major_allele            varchar(1) not null,
    minor_allele            varchar(10) not null,  /* note there could be  more than one but we are only loading first based on sorted list */
    major_allele_count        number(5) not null,
    minor_allele_count        number(5) not null,
    major_product            varchar(1),
    minor_product            varchar(1),
    distinct_strain_count            number(3), 
    distinct_allele_count            number(3),
    snp_id number(12) not null,
    modification_date  date
);

GRANT insert, select, update, delete ON ApiDB.SNP TO gus_w;
GRANT select ON ApiDB.SNP TO gus_r;

create sequence ApiDB.SNP_sq;

GRANT select ON ApiDB.SNP_sq TO gus_w;




create table apidb.SequenceVariation (
    external_database_release_id    number(10) not null,  /*  references sres.externaldatabaserelease */     
    snp_ext_db_rls_id    number(10) not null,  /*  references sres.externaldatabaserelease */     
    strain                varchar(50) not null,
    location            number(10) not null,
    allele                varchar(1) not null,
    matches_reference number(3) not null,
    product            varchar(1),
    p_value            FLOAT(126),
    read_percent            FLOAT(126),
    coverage            number(12),
    quality            number(12),
    na_sequence_id        number(10) not null,
    ref_na_sequence_id        number(10) not null,
    sequence_variation_id number(12) not null,
    modification_date  date
);

GRANT insert, select, update, delete ON ApiDB.SequenceVariation TO gus_w;
GRANT select ON ApiDB.SequenceVariation TO gus_r;

create sequence ApiDB.SequenceVariation_sq;

GRANT select ON ApiDB.SequenceVariation_sq TO gus_w;

