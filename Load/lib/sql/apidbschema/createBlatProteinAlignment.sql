create table apidb.BlatProteinAlignment ( 
        blat_protein_alignment_id number, 
        query_aa_sequence_id number not null, 
        target_na_sequence_id number not null, 
        query_table_id number, 
        query_taxon_id number, 
        query_external_db_release_id number, 
        target_table_id number, 
        target_taxon_id number, 
        target_external_db_release_id number, 
        is_consistent number not null, 
        is_genomic_contaminant number not null, 
        unaligned_3p_bases number not null, 
        unaligned_5p_bases number not null, 
        has_3p_polya number not null, 
        has_5p_polya number not null, 
        is_3p_complete number not null, 
        is_5p_complete number not null, 
        percent_identity number not null, 
        max_query_gap number not null, 
        max_target_gap number not null, 
        number_of_spans number not null, 
        query_start number not null,
        query_end number not null, 
        target_start number not null, 
        target_end number not null, 
        is_reversed number not null, 
        query_bases_aligned number not null, 
        repeat_bases_aligned number not null, 
        num_ns number not null, 
        score float not null, 
        is_best_alignment number not null,
        blat_alignment_quality_id number not null, 
        blocksizes varchar2(1600) not null, 
        qstarts varchar2(1600) not null, 
        tstarts varchar2(1600) not null,
        modification_date date not null, 
        user_read number not null, 
        user_write number not null, 
        group_read number not null, 
        group_write number not null,
        other_read number not null, 
        other_write number not null, 
        row_user_id number not null, 
        row_group_id number not null, 
        row_project_id number not null, 
        row_alg_invocation_id number not null, 
        constraint blatproteinalignment_fk01 foreign key (query_aa_sequence_id) references dots.aasequenceimp (aa_sequence_id) validate, 
        constraint blatproteinalignment_fk02 foreign key (target_na_sequence_id) references dots.nasequenceimp (na_sequence_id) validate, 
        constraint blatproteinalignment_fk03 foreign key (query_table_id) references core.tableinfo (table_id) validate, 
        constraint blatproteinalignment_fk04 foreign key (query_taxon_id) references sres.taxon (taxon_id) validate, 
        constraint blatproteinalignment_fk05 foreign key (query_external_db_release_id) references sres.externaldatabaserelease (external_database_release_id) validate,
        constraint blatproteinalignment_fk06 foreign key (target_table_id) references core.tableinfo (table_id) validate, 
        constraint blatproteinalignment_fk07 foreign key (target_taxon_id) references sres.taxon (taxon_id) validate, 
        constraint blatproteinalignment_fk08 foreign key (target_external_db_release_id) references sres.externaldatabaserelease (external_database_release_id) validate, 
        constraint blatproteinalignment_fk09 foreign key (blat_alignment_quality_id) references dots.blatalignmentquality (blat_alignment_quality_id) validate, 
        constraint pk_blatproteinalignment primary key (blat_protein_alignment_id) validate ) 
tablespace gus pctfree 10 initrans 1 maxtrans 255 storage ( initial 64k buffer_pool default) logging nocompress;

create sequence apidb.BlatProteinAlignment_sq;
grant select, alter on apidb.BlatProteinAlignment_sq to gus_w;

create index apidb.bpa_ix1 on apidb.BlatProteinAlignment (query_table_id, query_aa_sequence_id, query_start, query_end);
create index apidb.bpa_ix2 on apidb.BlatProteinAlignment (target_table_id, target_na_sequence_id, target_start, target_end);
create index apidb.bpa_ix3 on apidb.BlatProteinAlignment (query_taxon_id, blat_protein_alignment_id);
create index apidb.bpa_ix4 on apidb.BlatProteinAlignment (query_external_db_release_id, blat_protein_alignment_id);
create index apidb.bpa_ix5 on apidb.BlatProteinAlignment (target_taxon_id, blat_protein_alignment_id);
create index apidb.bpa_ix6 on apidb.BlatProteinAlignment (target_external_db_release_id, blat_protein_alignment_id);
create index apidb.bpa_ix7 on apidb.BlatProteinAlignment (blat_alignment_quality_id, blat_protein_alignment_id);
create index apidb.bpa_ix8 on apidb.BlatProteinAlignment (target_na_sequence_id, target_start, target_end, blat_protein_alignment_id);
create index apidb.bpa_ix9 on apidb.BlatProteinAlignment (query_aa_sequence_id, query_start, query_end, blat_protein_alignment_id);
create index apidb.bpa_ix0 on apidb.BlatProteinAlignment (modification_date, blat_protein_alignment_id);

grant select on apidb.BlatProteinAlignment to gus_r;
grant insert, update, delete on apidb.BlatProteinAlignment to gus_w;

insert into core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
select core.tableinfo_sq.nextval, 'BLATProteinAlignment',
       'Standard', 'blat_protein_alignment_id',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
from dual,
     (select max(project_id) as project_id from core.ProjectInfo) p,
     (select database_id from core.databaseinfo where lower(name) = 'apidb') d
where 'blatproteinalignment' not in (select lower(name)
                                     from core.TableInfo
                                     where database_id = d.database_id);

exit
