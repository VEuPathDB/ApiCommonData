set timing on

drop materialized view apidb.SnpSummary;

GRANT REFERENCES ON dots.SeqVariation TO apidb;
GRANT REFERENCES ON dots.SnpFeature TO apidb;
GRANT REFERENCES ON dots.SplicedNaSequence TO apidb;
GRANT REFERENCES ON dots.GeneFeature TO apidb;
GRANT REFERENCES ON sres.ExternalDatabase TO apidb;
GRANT REFERENCES ON sres.ExternalDatabaseRelease TO apidb;
GRANT REFERENCES ON sres.SequenceOntology TO apidb;

GRANT SELECT ON dots.SeqVariation TO apidb WITH GRANT OPTION;
GRANT SELECT ON dots.SnpFeature TO apidb WITH GRANT OPTION;
GRANT SELECT ON dots.SplicedNaSequence TO apidb WITH GRANT OPTION;
GRANT SELECT ON dots.GeneFeature TO apidb WITH GRANT OPTION;
GRANT SELECT ON sres.ExternalDatabaseRelease TO apidb WITH GRANT OPTION;
GRANT SELECT ON sres.ExternalDatabase TO apidb WITH GRANT OPTION;
GRANT SELECT ON sres.SequenceOntology TO apidb WITH GRANT OPTION;

-------------------------------------------------------------------------------

CREATE MATERIALIZED VIEW apidb.SnpSummary AS
SELECT cds_length, na_feature_id, source_id,
       strain_a, strain_b,
       sum(synonymous) as synonymous, 
       sum(non_synonymous) as non_synonymous, 
       sum(non_coding) as non_coding,
       sum(stop) as stop,
       sum(non_coding) + sum(synonymous) + sum(non_synonymous) as total
FROM  (SELECT greatest(taf.translation_start, taf.translation_stop)
              - least(taf.translation_start, taf.translation_stop) + 1 AS cds_length,
              gf.na_feature_id, gf.source_id,
              edr.external_database_release_id,
              SUBSTR(sva.strain, 1, 30) AS strain_a,
              SUBSTR(svb.strain, 1, 30) AS strain_b, 
              CASE WHEN sva.product IS NULL THEN 1 ELSE 0 END AS non_coding,
              CASE WHEN sva.product = svb.product THEN 1 ELSE 0 END AS synonymous,
              CASE WHEN sva.product != svb.product THEN 1 ELSE 0 END AS non_synonymous,
              CASE WHEN sva.product = '*' OR  svb.product = '*' THEN 1 ELSE 0 END AS stop
       FROM dots.SeqVariation sva, dots.SeqVariation svb, dots.SnpFeature sf,
            dots.SplicedNaSequence cds, dots.Transcript, dots.GeneFeature gf,
            dots.TranslatedAaFeature taf, sres.ExternalDatabase ed,
            sres.ExternalDatabaseRelease edr
       WHERE ed.name NOT IN ('Broad SNPs', 'Sanger falciparum SNPs',
                             'Su SNPs')
         AND sva.strain  < svb.strain
         AND sva.allele != svb.allele
         AND sva.parent_id = svb.parent_id
         AND sva.parent_id = sf.na_feature_id
         AND sf.parent_id = gf.na_feature_id
         AND sf.external_database_release_id = edr.external_database_release_id
         AND edr.external_database_id = ed.external_database_id
         AND gf.na_feature_id = transcript.parent_id
         AND transcript.na_sequence_id = cds.na_sequence_id
         AND transcript.na_feature_id = taf.na_feature_id
)
GROUP BY cds_length, na_feature_id, source_id,
         strain_a, strain_b;

CREATE INDEX apidb.SnpSummary_idx
       ON apidb.SnpSummary(na_feature_id, source_id);
CREATE INDEX apidb.SnpSummary_strain_idx
       ON apidb.SnpSummary(strain_a, strain_b, source_id);
CREATE INDEX apidb.SnpSummary_strainb_idx
       ON apidb.SnpSummary(strain_b, strain_a, source_id);
CREATE INDEX apidb.SnpSummary_srcId_idx
       ON apidb.SnpSummary(source_id, na_feature_id);

GRANT SELECT ON apidb.SnpSummary TO gus_r;

exit
