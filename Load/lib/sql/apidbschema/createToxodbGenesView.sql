GRANT SELECT ON dots.GeneFeature TO apidb WITH GRANT OPTION;
GRANT SELECT ON sres.ExternalDatabase TO apidb WITH GRANT OPTION;
GRANT SELECT ON sres.ExternalDatabaseRelease TO apidb WITH GRANT OPTION;
GRANT SELECT ON dots.GeneFeature TO gus_r;
GRANT SELECT ON sres.ExternalDatabase TO gus_r;
GRANT SELECT ON sres.ExternalDatabaseRelease TO gus_r;

CREATE VIEW apidb.ToxodbGenes AS
SELECT *
FROM dots.GeneFeature gf
WHERE gf.external_database_release_id IN
      (SELECT edr.external_database_release_id
       FROM sres.ExternalDatabaseRelease edr,
            sres.ExternalDatabase ed
       WHERE edr.external_database_id = ed.external_database_id
         AND ed.name in  ('Chromosome Map - David Sibley', 'Roos Lab T. gondii apicoplast'));

GRANT SELECT ON apidb.ToxodbGenes TO gus_r;

exit;
