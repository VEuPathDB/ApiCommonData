/* purpose to set secondary identifier so can use the mrf4 reagents query */

update sres.dbref set secondary_identifier = 'antibody' where db_ref_id in (
                  SELECT dbr.db_ref_id 
               FROM dots.GeneFeature gf,
                dots.DbRefAaFeature df,
                sres.DbRef dbr, sres.ExternalDatabaseRelease edr,
                sres.ExternalDatabase ed, dots.TranslatedAAFeature taf,
                dots.Transcript t
               WHERE ed.name in ('MR4DBxRefs','AntibodyDBxRefs')
                 AND edr.external_database_id = ed.external_database_id
                 AND dbr.external_database_release_id = edr.external_database_release_id
                 AND df.db_ref_id = dbr.db_ref_id
                 AND taf.aa_feature_id = df.aa_feature_id
                 AND t.na_feature_id = taf.na_feature_id
                 AND gf.na_feature_id = t.parent_id);

commit;

quit;
