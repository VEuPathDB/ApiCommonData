create table apidb.Variant (
    na_sequence_id               NUMBER(10) not null,/* references dots.nasequence */
    gene_na_feature_id           NUMBER(10) not null, /* references dots.transcript */
    location                     NUMBER(10) not null,
    variant_id                   NUMBER(12) not null,
    source_id                    varchar(100) not null,
    reference_strain             varchar(50) not null,
    reference_na                 varchar(10) not null,
    reference_aa                 varchar(1),
    external_database_release_id NUMBER(10) not null,/* references sres.externaldatabaserelease */
    has_nonsynonymous_allele     NUMBER(1),  /* if 1 then at least one allele non-synonymous .. not sure in practice that we use this */
    major_allele                 varchar(10) not null,
    minor_allele                 varchar(10) not null,  /* note there could be  more than one but we are only loading first based on sorted list */
    major_allele_count           NUMBER(5) not null,
    minor_allele_count           NUMBER(5) not null,
    total_allele_count           NUMBER(5),
    major_product                varchar(5),
    minor_product                varchar(5),
    distinct_strain_count        NUMBER(3),
    distinct_allele_count        NUMBER(3),
    has_coding_mutation          NUMBER(1),
    has_stop_codon               NUMBER(1),
    ref_codon                    varchar(3),
    modification_date            date,
    USER_READ                    NUMBER(1),
    USER_WRITE                   NUMBER(1),
    GROUP_READ                   NUMBER(1),
    GROUP_WRITE                  NUMBER(1),
    OTHER_READ                   NUMBER(1),
    OTHER_WRITE                  NUMBER(1),
    ROW_USER_ID                  NUMBER(12),
    ROW_GROUP_ID                 NUMBER(3),
    ROW_PROJECT_ID               NUMBER(4),
    ROW_ALG_INVOCATION_ID        NUMBER(12),
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
SELECT core.tableinfo_sq.nextval, 'Variant',
       'Standard', 'variant_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'variant' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

--------------------------------------------------------------------------------
-- TODO Add ApiDB.VariantProductSummary

create table apidb.VariantProductSummary (
    variant_product_id           NUMBER(12) not null,
    transcript_na_feature_id     varchar(20), /* references dots.NaFeatureImp */
    codon                        varchar(3),
    position_in_codon            NUMBER(1),
    count                        NUMBER(5),
    product                      varchar(1),
    ref_location_cds             varchar(2500),
    ref_location_protein         varchar(2500),
    modification_date            date,
    USER_READ                    NUMBER(1),
    USER_WRITE                   NUMBER(1),
    GROUP_READ                   NUMBER(1),
    GROUP_WRITE                  NUMBER(1),
    OTHER_READ                   NUMBER(1),
    OTHER_WRITE                  NUMBER(1),
    ROW_USER_ID                  NUMBER(12),
    ROW_GROUP_ID                 NUMBER(3),
    ROW_PROJECT_ID               NUMBER(4),
    ROW_ALG_INVOCATION_ID        NUMBER(12),
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
SELECT core.tableinfo_sq.nextval, 'VariantProductSummary',
       'Standard', 'VARIANT_PRODUCT_ID',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'variantproductsummary' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);


--------------------------------------------------------------------------------
-- TODO Add ApiDB.VariantAlleleSummary
create table apidb.VariantAlleleSummary (
    variant_allele_id            NUMBER(12) not null,
    allele                       varchar(10) not null,
    distinct_strain_count        NUMBER(3),
    allele_count                 NUMBER(3),
    average_coverage             decimal(10,2),
    average_read_percent         decimal(10,2),
    modification_date            date,
    USER_READ                    NUMBER(1),
    USER_WRITE                   NUMBER(1),
    GROUP_READ                   NUMBER(1),
    GROUP_WRITE                  NUMBER(1),
    OTHER_READ                   NUMBER(1),
    OTHER_WRITE                  NUMBER(1),
    ROW_USER_ID                  NUMBER(12),
    ROW_GROUP_ID                 NUMBER(3),
    ROW_PROJECT_ID               NUMBER(4),
    ROW_ALG_INVOCATION_ID        NUMBER(12),
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
SELECT core.tableinfo_sq.nextval, 'VariantAlleleSummary',
       'Standard', 'VARIANT_ALLELE_ID',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'variantallelesummary' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    WHERE database_id = d.database_id);

exit;
