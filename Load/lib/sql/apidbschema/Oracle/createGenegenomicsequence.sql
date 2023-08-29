create table apidb.Genegenomicsequence (
  source_id VARCHAR2(255) NOT NULL,   
  gene_genomic_sequence CLOB 

);

ALTER TABLE apidb.Genegenomicsequence
ADD CONSTRAINT source_id_pk PRIMARY KEY (source_id);

GRANT SELECT ON apidb.genegenomicsequence TO gus_r;
GRANT SELECT ON apidb.genegenomicsequence TO gus_w;

exit;
