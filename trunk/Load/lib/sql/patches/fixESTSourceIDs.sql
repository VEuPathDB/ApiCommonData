- ApiCommonData::Load::Plugin::InsertDbESTFiles
- puts an id from the DEFINITION (eg. CpEST.323) 
- instead of the ACCESSION
- into dots.externalnasequence.source_id.
- Copy dots.est.accession to enas.source_id to correct this.

UPDATE dots.externalnasequence enas
SET source_id = (
    SELECT e.accession
    FROM  dots.est e
    WHERE enas.na_sequence_id = e.na_sequence_id
)
WHERE enas.na_sequence_id = (
    SELECT e.na_sequence_id
    FROM  dots.est e
    WHERE enas.na_sequence_id = e.na_sequence_id
)

