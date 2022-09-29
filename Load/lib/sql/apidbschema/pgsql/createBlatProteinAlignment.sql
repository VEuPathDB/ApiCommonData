create table apidb.BlatProteinAlignment (
    blat_protein_alignment_id     NUMERIC,
    query_aa_sequence_id          NUMERIC       not null,
    target_na_sequence_id         NUMERIC       not null,
    query_table_id                NUMERIC,
    query_taxon_id                NUMERIC,
    query_external_db_release_id  NUMERIC,
    target_table_id               NUMERIC,
    target_taxon_id               NUMERIC,
    target_external_db_release_id NUMERIC,
    is_consistent                 NUMERIC       not null,
    is_genomic_contaminant        NUMERIC       not null,
    unaligned_3p_bases            NUMERIC       not null,
    unaligned_5p_bases            NUMERIC       not null,
    has_3p_polya                  NUMERIC       not null,
    has_5p_polya                  NUMERIC       not null,
    is_3p_complete                NUMERIC       not null,
    is_5p_complete                NUMERIC       not null,
    percent_identity              NUMERIC       not null,
    max_query_gap                 NUMERIC       not null,
    max_target_gap                NUMERIC       not null,
    number_of_spans               NUMERIC       not null,
    query_start                   NUMERIC       not null,
    query_end                     NUMERIC       not null,
    target_start                  NUMERIC       not null,
    target_end                    NUMERIC       not null,
    is_reversed                   NUMERIC       not null,
    query_bases_aligned           NUMERIC       not null,
    repeat_bases_aligned          NUMERIC       not null,
    num_ns                        NUMERIC       not null,
    score                         float         not null,
    is_best_alignment             NUMERIC       not null,
    blat_alignment_quality_id     NUMERIC       not null,
    blocksizes                    varchar(1600) not null,
    qstarts                       varchar(1600) not null,
    tstarts                       varchar(1600) not null,
    modification_date             date          not null,
    user_read                     NUMERIC       not null,
    user_write                    NUMERIC       not null,
    group_read                    NUMERIC       not null,
    group_write                   NUMERIC       not null,
    other_read                    NUMERIC       not null,
    other_write                   NUMERIC       not null,
    row_user_id                   NUMERIC       not null,
    row_group_id                  NUMERIC       not null,
    row_project_id                NUMERIC       not null,
    row_alg_invocation_id         NUMERIC       not null,
    constraint blatproteinalignment_fk01 foreign key (query_aa_sequence_id) references dots.aasequenceimp(aa_sequence_id),
    constraint blatproteinalignment_fk02 foreign key (target_na_sequence_id) references dots.nasequenceimp(na_sequence_id),
    constraint blatproteinalignment_fk03 foreign key (query_table_id) references core.tableinfo(table_id),
    constraint blatproteinalignment_fk04 foreign key (query_taxon_id) references sres.taxon(taxon_id),
    constraint blatproteinalignment_fk05 foreign key (query_external_db_release_id) references sres.externaldatabaserelease(external_database_release_id),
    constraint blatproteinalignment_fk06 foreign key (target_table_id) references core.tableinfo(table_id),
    constraint blatproteinalignment_fk07 foreign key (target_taxon_id) references sres.taxon(taxon_id),
    constraint blatproteinalignment_fk08 foreign key (target_external_db_release_id) references sres.externaldatabaserelease(external_database_release_id),
    constraint blatproteinalignment_fk09 foreign key (blat_alignment_quality_id) references dots.blatalignmentquality(blat_alignment_quality_id),
    constraint pk_blatproteinalignment primary key (blat_protein_alignment_id)
);
--tablespace gus pctfree 10 initrans 1 maxtrans 255 storage ( initial 64k buffer_pool default) logging nocompress;
--TODO adjust & enable tablespace definition if relevant

create sequence apidb.BlatProteinAlignment_sq;

--grant select, alter on apidb.BlatProteinAlignment_sq to gus_w;
grant select on apidb.BlatProteinAlignment_sq to gus_w;

create index bpa_ix1 on apidb.BlatProteinAlignment (query_table_id, query_aa_sequence_id, query_start, query_end) tablespace indx;
create index bpa_ix2 on apidb.BlatProteinAlignment (target_table_id, target_na_sequence_id, target_start, target_end) tablespace indx;
create index bpa_ix3 on apidb.BlatProteinAlignment (query_taxon_id, blat_protein_alignment_id) tablespace indx;
create index bpa_ix4 on apidb.BlatProteinAlignment (query_external_db_release_id, blat_protein_alignment_id) tablespace indx;
create index bpa_ix5 on apidb.BlatProteinAlignment (target_taxon_id, blat_protein_alignment_id) tablespace indx;
create index bpa_ix6 on apidb.BlatProteinAlignment (target_external_db_release_id, blat_protein_alignment_id) tablespace indx;
create index bpa_ix7 on apidb.BlatProteinAlignment (blat_alignment_quality_id, blat_protein_alignment_id) tablespace indx;
create index bpa_ix8 on apidb.BlatProteinAlignment (target_na_sequence_id, target_start, target_end, blat_protein_alignment_id) tablespace indx;
create index bpa_ix9 on apidb.BlatProteinAlignment (query_aa_sequence_id, query_start, query_end, blat_protein_alignment_id) tablespace indx;
create index bpa_ix0 on apidb.BlatProteinAlignment (modification_date, blat_protein_alignment_id) tablespace indx;

-- index columns with foreign-key constraints, to avoid performance problems when
-- deleting records or updating the primary-key column in the reerenced tables
create index bpa_revix1 on apidb.BlatProteinAlignment (query_aa_sequence_id, blat_protein_alignment_id) tablespace indx;
create index bpa_revix3 on apidb.BlatProteinAlignment (query_table_id, blat_protein_alignment_id) tablespace indx;
create index bpa_revix6 on apidb.BlatProteinAlignment (target_table_id, blat_protein_alignment_id) tablespace indx;

grant select on apidb.BlatProteinAlignment to gus_r;
grant insert, update, delete on apidb.BlatProteinAlignment to gus_w;

insert into core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
select NEXTVAL('core.tableinfo_sq'), 'BLATProteinAlignment',
       'Standard', 'blat_protein_alignment_id',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
from
     (select max(project_id) as project_id from core.ProjectInfo) p,
     (select database_id from core.databaseinfo where lower(name) = 'apidb') d
where 'blatproteinalignment' not in (select lower(name)
                                     from core.TableInfo
                                     where database_id = d.database_id);


