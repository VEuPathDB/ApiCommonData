create table apidb.GENEGENOMICSEQUENCE_SPLIT (
    source_id VARCHAR2(255) NOT NULL,
    gene_genomic_sequence CLOB,
    start_min NUMBER(12) NOT NULL
);

ALTER TABLE apidb.GENEGENOMICSEQUENCE_SPLIT
ADD CONSTRAINT source_id_pk PRIMARY KEY (source_id);

create index ggss_source_id_indx  on apidb.GENEGENOMICSEQUENCE_SPLIT(source_id);

GRANT SELECT ON apidb.GENEGENOMICSEQUENCE_SPLIT TO gus_r;
GRANT SELECT ON apidb.GENEGENOMICSEQUENCE_SPLIT TO gus_w;

exit;
