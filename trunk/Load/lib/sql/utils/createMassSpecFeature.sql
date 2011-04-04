DROP MATERIALIZED VIEW apidb.MassSpecFeature;

CREATE MATERIALIZED VIEW apidb.MassSpecFeature AS
SELECT t.na_sequence_id, nal.start_max, nal.end_max,
       nal.na_feature_id feature_id,
       'Peptide' type,
       DECODE(SUBSTR(ed.name, 1, 6),
              'Murray', 'MurrayMassSpecPeptides',
              'Wastli', 'WastlingMassSpecPeptides',
              ed.name) source,
       nal.start_max startm,
       nal.end_max end,
			nal.na_feature_id parent_id,
       decode (nal.is_reversed, 0, '+1', 1, '-1', '.') strand,
       SUBSTR('Description=' || msf.description || '|' ||
              'ExtDbName=' || ed.name || '|' ||
              'PepSeq=' ||
              SUBSTR(aas.sequence, aal.start_min,
                     aal.end_max - aal.start_min + 1) || '|' ||
             'SOTerm=' || term_name, 1, 400) atts
FROM dots.nalocation nal,
     dots.massspecfeature msf,
     dots.translatedaafeature taaf,
     ( select gf.na_sequence_id, t.na_feature_id, term_name
        from dots.nafeature gf, dots.nafeature t,
        sres.sequenceontology sres
        where  gf.na_feature_id =  t.parent_id
        and gf.sequence_ontology_id = sres.sequence_ontology_id
        UNION
        SELECT na_sequence_id, na_feature_id, term_name
        FROM   dots.miscellaneous misc, sres.sequenceontology sres
        WHERE  misc.sequence_ontology_id = sres.sequence_ontology_id
     ) t,
     dots.aasequence aas, dots.aalocation aal,
--   dots.virtualsequence vs,
     sres.externaldatabaserelease edr,
     sres.externaldatabase ed
WHERE nal.na_feature_id = msf.na_feature_id
 AND  taaf.aa_sequence_id = msf.aa_sequence_id
 AND  taaf.na_feature_id = t.na_feature_id
-- AND  t.na_sequence_id = vs.na_sequence_id
 AND  msf.external_database_release_id = edr.external_database_release_id
 AND  edr.external_database_id = ed.external_database_id
 AND  edr.external_database_id = ed.external_database_id
 AND  aal.aa_feature_id = msf.aa_feature_id
 AND  msf.aa_sequence_id = aas.aa_sequence_id;

GRANT SELECT ON apidb.MassSpecFeature TO gus_r;

CREATE INDEX apidb.msf_loc_ix
             ON apidb.MassSpecFeature
                (source, na_sequence_id, start_max, end_max);


exit
