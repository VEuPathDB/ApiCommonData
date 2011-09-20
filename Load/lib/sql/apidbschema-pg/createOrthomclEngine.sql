-- KEEP THIS SCHEMA IN SYNC WITH OrthoMCLEngine/Main/bin/orthomclInstallSchema

CREATE TABLE apidb.SimilarSequences (
 QUERY_ID                 VARCHAR(60),
 SUBJECT_ID               VARCHAR(60),
 QUERY_TAXON_ID           VARCHAR(40),
 SUBJECT_TAXON_ID         VARCHAR(40),
 EVALUE_MANT              FLOAT,
 EVALUE_EXP               NUMERIC,
 PERCENT_IDENTITY         FLOAT,
 PERCENT_MATCH            FLOAT  
) ;


CREATE INDEX ss_qtaxexp_ix ON apidb.SimilarSequences(query_id, subject_taxon_id, evalue_exp, evalue_mant, query_taxon_id, subject_id) ;
CREATE INDEX ss_seqs_ix on apidb.SimilarSequences(query_id, subject_id, evalue_exp, evalue_mant, percent_match);

-----------------------------------------------------------

create view apidb.InterTaxonMatch as
select ss.query_id, ss.subject_id, ss.subject_taxon_id,
       ss.evalue_mant, ss.evalue_exp
from apidb.SimilarSequences ss
where ss.subject_taxon_id != ss.query_taxon_id;




------------------------------------------------------------------

CREATE TABLE apidb.Inparalog (
 SEQUENCE_ID_A           VARCHAR(60),
 SEQUENCE_ID_B           VARCHAR(60),
 TAXON_ID                VARCHAR(40),
 UNNORMALIZED_SCORE      FLOAT,
 NORMALIZED_SCORE        FLOAT    
);


CREATE INDEX inparalog_seqa_ix
ON apidb.inparalog (sequence_id_a);

CREATE INDEX inparalog_seqb_ix
ON apidb.inparalog (sequence_id_b);
------------------------------------------------------------

CREATE TABLE apidb.Ortholog (
 SEQUENCE_ID_A           VARCHAR(60),
 SEQUENCE_ID_B           VARCHAR(60),
 TAXON_ID_A              VARCHAR(40),
 TAXON_ID_B              VARCHAR(40),
 UNNORMALIZED_SCORE      FLOAT,
 NORMALIZED_SCORE        FLOAT    
);

CREATE INDEX ortholog_seq_a_ix on apidb.ortholog(sequence_id_a) ;
CREATE INDEX ortholog_seq_b_ix on apidb.ortholog(sequence_id_b) ;



------------------------------------------------------------
 
CREATE TABLE apidb.CoOrtholog (
 SEQUENCE_ID_A           VARCHAR(60),
 SEQUENCE_ID_B           VARCHAR(60),
 TAXON_ID_A              VARCHAR(40),
 TAXON_ID_B              VARCHAR(40),
 UNNORMALIZED_SCORE      FLOAT,
 NORMALIZED_SCORE        FLOAT    
);



---------------------------------------------------------------
