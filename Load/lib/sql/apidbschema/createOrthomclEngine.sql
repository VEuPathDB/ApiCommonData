-- KEEP THIS SCHEMA IN SYNC WITH OrthoMCLEngine/Main/bin/orthomclInstallSchema

CREATE TABLE apidb.SimilarSequences (
 QUERY_ID                 VARCHAR(60),
 SUBJECT_ID               VARCHAR(60),
 QUERY_TAXON_ID           VARCHAR(40),
 SUBJECT_TAXON_ID         VARCHAR(40),
 EVALUE_MANT              FLOAT,
 EVALUE_EXP               NUMBER,
 PERCENT_IDENTITY         FLOAT,
 PERCENT_MATCH            FLOAT  
) NOLOGGING;

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.SimilarSequences TO gus_w;
GRANT SELECT ON apidb.SimilarSequences TO gus_r;

CREATE INDEX apidb.ss_qtaxexp_ix ON apidb.SimilarSequences(query_id, subject_taxon_id, evalue_exp, evalue_mant, query_taxon_id, subject_id) NOLOGGING TABLESPACE INDX;
CREATE INDEX apidb.ss_seqs_ix on apidb.SimilarSequences(query_id, subject_id, evalue_exp, evalue_mant, percent_match) NOLOGGING TABLESPACE INDX;

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
 SEQUENCE_ID_A           VARCHAR(60),
 SEQUENCE_ID_B           VARCHAR(60),
 TAXON_ID                VARCHAR(40),
 UNNORMALIZED_SCORE      FLOAT,
 NORMALIZED_SCORE        FLOAT    
);

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.Inparalog TO gus_w;
GRANT SELECT ON apidb.Inparalog TO gus_r;

CREATE INDEX apidb.inparalog_seqa_ix
ON apidb.inparalog (sequence_id_a)
TABLESPACE indx;

CREATE INDEX apidb.inparalog_seqb_ix
ON apidb.inparalog (sequence_id_b)
TABLESPACE indx;
------------------------------------------------------------

CREATE TABLE apidb.Ortholog (
 SEQUENCE_ID_A           VARCHAR(60),
 SEQUENCE_ID_B           VARCHAR(60),
 TAXON_ID_A              VARCHAR(40),
 TAXON_ID_B              VARCHAR(40),
 UNNORMALIZED_SCORE      FLOAT,
 NORMALIZED_SCORE        FLOAT    
);

CREATE INDEX apidb.ortholog_seq_a_ix on apidb.ortholog(sequence_id_a) TABLESPACE indx;
CREATE INDEX apidb.ortholog_seq_b_ix on apidb.ortholog(sequence_id_b) TABLESPACE indx;


GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.ortholog TO gus_w;
GRANT SELECT ON apidb.ortholog TO gus_r;

------------------------------------------------------------
 
CREATE TABLE apidb.CoOrtholog (
 SEQUENCE_ID_A           VARCHAR(60),
 SEQUENCE_ID_B           VARCHAR(60),
 TAXON_ID_A              VARCHAR(40),
 TAXON_ID_B              VARCHAR(40),
 UNNORMALIZED_SCORE      FLOAT,
 NORMALIZED_SCORE        FLOAT    
);


GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.coortholog TO gus_w;
GRANT SELECT ON apidb.coortholog TO gus_r;

---------------------------------------------------------------

exit;
