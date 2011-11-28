CREATE TABLE apidb.transmembrane (
source_id character varying(50) NOT NULL,
transmembrane_count NUMERIC(5) NOT NULL);

-- also works in Oracle with s/coalesce/nvl/
INSERT INTO apidb.transmembrane (source_id, transmembrane_count)
SELECT gf.source_id, coalesce(tm_domains, 0) as tm_count
FROM dots.GeneFeature gf
left join (SELECT source_id, max(tm_domains) AS tm_domains
      FROM (SELECT gf.source_id, tmaf.aa_feature_id, count(*) as tm_domains
            FROM dots.GeneFeature gf, dots.NaSequence ns,
                 dots.Transcript t, dots.TranslatedAaFeature tlaf,
                 dots.TransmembraneAaFeature tmaf, dots.AaLocation al
            WHERE gf.na_sequence_id = ns.na_sequence_id
              AND gf.na_feature_id = t.parent_id
              AND t.na_feature_id = tlaf.na_feature_id
              AND tlaf.aa_sequence_id = tmaf.aa_sequence_id
              AND tmaf.aa_feature_id = al.aa_feature_id
            GROUP BY gf.source_id, tmaf.aa_feature_id) tms
      GROUP BY tms.source_id) max_tms on gf.source_id = max_tms.source_id;
