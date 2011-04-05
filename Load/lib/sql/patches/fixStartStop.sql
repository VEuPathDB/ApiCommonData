-- update gene start_min

update dots.NaLocation
set start_min = (select least(min(nl2.start_min), min(nl2.end_max))
                    from dots.ExonFeature ef, dots.NaLocation nl2
                    where ef.parent_id = NaLocation.na_feature_id
                      and ef.na_feature_id = nl2.na_feature_id)
where na_feature_id in (select gf.na_feature_id
                           from dots.GeneFeature gf,
                                sres.ExternalDatabaseRelease edr,
                                sres.ExternalDatabase ed
                           where gf.external_database_release_id = edr.external_database_release_id
                             and edr.external_database_id = ed.external_database_id
                             and ed.name in ('Jane Carlton P. vivax chromosomes',
                                             'Jane Carlton P. yoelii chromosomes'))
  and is_reversed = 1;

-- update gene start_max
update dots.NaLocation
set start_max = start_min
where na_feature_id in (select gf.na_feature_id
                           from dots.GeneFeature gf,
                                sres.ExternalDatabaseRelease edr,
                                sres.ExternalDatabase ed
                           where gf.external_database_release_id = edr.external_database_release_id
                             and edr.external_database_id = ed.external_database_id
                             and ed.name in ('Jane Carlton P. vivax chromosomes',
                                             'Jane Carlton P. yoelii chromosomes'))
  and is_reversed = 1;

-- update gene end_min

update dots.NaLocation
set end_min = (select greatest(max(nl2.start_min), max(nl2.end_max))
                    from dots.ExonFeature ef, dots.NaLocation nl2
                    where ef.parent_id = NaLocation.na_feature_id
                      and ef.na_feature_id = nl2.na_feature_id)
where na_feature_id in (select gf.na_feature_id
                           from dots.GeneFeature gf,
                                sres.ExternalDatabaseRelease edr,
                                sres.ExternalDatabase ed
                           where gf.external_database_release_id = edr.external_database_release_id
                             and edr.external_database_id = ed.external_database_id
                             and ed.name in ('Jane Carlton P. vivax chromosomes',
                                             'Jane Carlton P. yoelii chromosomes'))
  and is_reversed = 1;

-- update gene end_max
update dots.NaLocation
set end_max = end_min
where na_feature_id in (select gf.na_feature_id
                           from dots.GeneFeature gf,
                                sres.ExternalDatabaseRelease edr,
                                sres.ExternalDatabase ed
                           where gf.external_database_release_id = edr.external_database_release_id
                             and edr.external_database_id = ed.external_database_id
                             and ed.name in ('Jane Carlton P. vivax chromosomes',
                                             'Jane Carlton P. yoelii chromosomes'))
  and is_reversed = 1;
