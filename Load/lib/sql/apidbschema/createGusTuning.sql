-- indexes on GUS tables

create index dots.AaSeq_source_ix on dots.AaSequenceImp (lower(source_id)) tablespace INDX;
create index dots.AaSeq_2ary_ix on dots.AaSequenceImp (string1, aa_sequence_id) tablespace INDX;

-- GUS table shortcomings

ALTER TABLE core.AlgorithmParam MODIFY (string_value VARCHAR2(2000));
ALTER TABLE coreVer.AlgorithmParamVer MODIFY (string_value VARCHAR2(2000));

ALTER TABLE sres.DbRef MODIFY (secondary_identifier varchar2(100));
ALTER TABLE sresVer.DbRefVer MODIFY (secondary_identifier varchar2(100));

ALTER TABLE sres.GoSynonym MODIFY (text VARCHAR2(1000));
ALTER TABLE sresVer.GoSynonymVer MODIFY (text VARCHAR2(1000));

ALTER TABLE sres.GoEvidenceCode       MODIFY (description VARCHAR2(1500));
ALTER TABLE sresVer.GoEvidenceCodeVer MODIFY (description VARCHAR2(1500));
ALTER TABLE sres.GoEvidenceCode       MODIFY (name VARCHAR2(5));
ALTER TABLE sresVer.GoEvidenceCodeVer MODIFY (name VARCHAR2(5)); 

ALTER TABLE rad.Analysis ADD name VARCHAR2(200);
ALTER TABLE radVer.AnalysisVer ADD name VARCHAR2(200);

exit
