create table apidb.Variant (
    na_sequence_id               NUMERIC(10) not null,/* references dots.NaSequenceImp */
    location                     NUMERIC(10) not null,
    variant_id                       NUMERIC(12) not null,
    transcript_na_feature_id           NUMERIC(10), /* references dots.NaFeatureImp */
-- TODO:  add variant fields
"gene_na_feature_id",

    source_id                    varchar(100) not null,
    reference_strain             varchar(50) not null,
    reference_na                 varchar(1) not null,
    reference_aa                 varchar(1),
    external_database_release_id NUMERIC(10) not null,/* references sres.externaldatabaserelease */
    has_nonsynonymous_allele     NUMERIC(1),  /* if 1 then at least one allele non-synonymous .. not sure in practice that we use this */
    major_allele                 varchar(1) not null,
    minor_allele                 varchar(10) not null,  /* note there could be  more than one but we are only loading first based on sorted list */
    major_allele_count           NUMERIC(5) not null,
    minor_allele_count           NUMERIC(5) not null,
    total_allele_count           NUMERIC(5),
    major_product                varchar(1),
    minor_product                varchar(1),
    distinct_strain_count        NUMERIC(3),
    distinct_allele_count        NUMERIC(3),
    has_coding_mutation                    NUMERIC(1),
    has_stop_codon               NUMERIC(1),
    ref_codon
    reference_aa_full            varchar(2500),
    modification_date            TIMESTAMP,
    PRIMARY KEY (variant_id)
);

create sequence apidb.Variant_sq;

-- no indexes created in this file for this table.  they are created by addConstraintsAndIndexesToSnpTables.sql instead, to be run at the end of workflow

grant select on apidb.variant to gus_r;
grant insert, select, update, delete on apidb.variant to gus_w;
grant select ON apidb.variant_sq TO gus_w;


-- Maybe don't need this if we use bulk loader.
INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'Variant',
       'Standard', 'variant_id',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'snp' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);



--------------------------------------------------------------------------------
-- TODO Add ApiDB.VariantProductSummary

create table apidb.VariantProductSummary (
    na_sequence_id               NUMERIC(10) not null,/* references dots.NaSequenceImp */
    location                     NUMERIC(10) not null,
    variant_product_id                       NUMERIC(12) not null,
    transcript_na_feature_id           NUMERIC(10), /* references dots.NaFeatureImp */
    codon varchar(3),
    position_in_codon            NUMERIC(1),
    transcript
    count
    product varchar(1)
    ref_location_cds        varchar(2500),
    ref_location_protein        varchar(2500),
    external_database_release_id NUMERIC(10) not null,/* references sres.externaldatabaserelease */
    modification_date            TIMESTAMP,
    PRIMARY KEY (variant_product_id)
);

create sequence apidb.VariantProductSummary_sq;

-- no indexes created in this file for this table.  they are created by addConstraintsAndIndexesToSnpTables.sql instead, to be run at the end of workflow

grant select on apidb.variantproductsummary to gus_r;
grant insert, select, update, delete on apidb.variantproductsummary to gus_w;
grant select ON apidb.variantproductsummary_sq TO gus_w;

-- Maybe don't need this if we use bulk loader.
INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'VariantProductSummary',
       'Standard', 'variant_product_id',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'snp' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);




--------------------------------------------------------------------------------
-- TODO Add ApiDB.VariantAlleleSummary
create table apidb.VariantAlleleSummary (
    na_sequence_id               NUMERIC(10) not null,/* references dots.NaSequenceImp */
    location                     NUMERIC(10) not null,
    variant_allele_id                       NUMERIC(12) not null,
    transcript_na_feature_id           NUMERIC(10), /* references dots.NaFeatureImp */
-- TODO:  add variant fields
-- source_id                    varchar(100) not null,
    -- reference_strain             varchar(50) not null,
    -- reference_na                 varchar(1) not null,
    -- reference_aa                 varchar(1),
    -- position_in_cds              NUMERIC(5),
    -- position_in_protein          NUMERIC(5),
    -- external_database_release_id NUMERIC(10) not null,/* references sres.externaldatabaserelease */
    -- has_nonsynonymous_allele     NUMERIC(1),  /* if 1 then at least one allele non-synonymous .. not sure in practice that we use this */
    -- major_allele                 varchar(1) not null,
    -- minor_allele                 varchar(10) not null,  /* note there could be  more than one but we are only loading first based on sorted list */
    -- major_allele_count           NUMERIC(5) not null,
    -- minor_allele_count           NUMERIC(5) not null,
    -- total_allele_count           NUMERIC(5),
    -- major_product                varchar(1),
    -- minor_product                varchar(1),
    -- distinct_strain_count        NUMERIC(3),
    -- distinct_allele_count        NUMERIC(3),
    -- is_coding                    NUMERIC(1),
    -- has_stop_codon               NUMERIC(1),
    -- positions_in_cds_full        varchar(2500),
    -- positions_in_protein_full    varchar(2500),
    -- reference_aa_full            varchar(2500),
    modification_date            TIMESTAMP,
    PRIMARY KEY (variant_allele_id)
);

create sequence apidb.VariantAlleleSummary_sq;

-- no indexes created in this file for this table.  they are created by addConstraintsAndIndexesToSnpTables.sql instead, to be run at the end of workflow

grant select on apidb.variantallelesummary to gus_r;
grant insert, select, update, delete on apidb.variantallelesummary to gus_w;
grant select ON apidb.variantallelesummary_sq TO gus_w;


-- Maybe don't need this if we use bulk loader.
INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT NEXTVAL('core.tableinfo_sq'), 'VariantAlleleSummary',
       'Standard', 'variant_allele_id',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'snp' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);
