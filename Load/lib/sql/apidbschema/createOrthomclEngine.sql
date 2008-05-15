CREATE TABLE apidb.SimilarSequences (
 QUERY_ID                 NUMBER(10),
 SUBJECT_ID               NUMBER(10),
 QUERY_TAXON_ID           NUMBER(10),
 SUBJECT_TAXON_ID         NUMBER(10),
 EVALUE_MANT              FLOAT(126),
 EVALUE_EXP               NUMBER,
 PERCENT_IDENTITY         NUMBER,
 PERCENT_MATCH            NUMBER  
);

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.SimilarSequences TO gus_w;
GRANT SELECT ON apidb.SimilarSequences TO gus_r;

CREATE INDEX apidb.ss_qtaxexp_ix ON apidb.SimilarSequences(query_id, subject_taxon_id, evalue_exp, evalue_mant, query_taxon_id, subject_id);
CREATE INDEX apidb.ss_seqs_ix on apidb.SimilarSequences(query_id, subject_id, evalue_exp, evalue_mant);

-----------------------------------------------------------

create view apidb.InterTaxonMatch as
select ss.query_id, ss.subject_id, ss.subject_taxon_id,
       ss.evalue_mant, ss.evalue_exp
from apidb.SimilarSequences ss
where ss.subject_taxon_id != ss.query_taxon_id;


GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.interTaxonMatch TO gus_w;
GRANT SELECT ON apidb.InterTaxonMatch TO gus_r;


------------------------------------------------------------------

CREATE TABLE apidb.Inparalog (
 SEQUENCE_ID_A           NUMBER(10),
 SEQUENCE_ID_B           NUMBER(10),
 TAXON_ID                NUMBER(10),
 UNNORMALIZED_SCORE      NUMBER,
 NORMALIZED_SCORE        NUMBER    
);

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.Inparalog TO gus_w;
GRANT SELECT ON apidb.Inparalog TO gus_r;

------------------------------------------------------------

CREATE TABLE apidb.Ortholog (
 SEQUENCE_ID_A           NUMBER(10),
 SEQUENCE_ID_B           NUMBER(10),
 TAXON_ID_A              NUMBER(10),
 TAXON_ID_B              NUMBER(10),
 UNNORMALIZED_SCORE      NUMBER,
 NORMALIZED_SCORE        NUMBER    
);

CREATE INDEX apidb.ortholog_seq_a_ix on apidb.ortholog(sequence_id_a);
CREATE INDEX apidb.ortholog_seq_b_ix on apidb.ortholog(sequence_id_b);


GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.ortholog TO gus_w;
GRANT SELECT ON apidb.ortholog TO gus_r;

------------------------------------------------------------
 
CREATE TABLE apidb.CoOrtholog (
 SEQUENCE_ID_A           NUMBER(10),
 SEQUENCE_ID_B           NUMBER(10),
 UNNORMALIZED_SCORE      NUMBER,
 NORMALIZED_SCORE        NUMBER    
);


GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.coortholog TO gus_w;
GRANT SELECT ON apidb.coortholog TO gus_r;

---------------------------------------------------------------

exit;
