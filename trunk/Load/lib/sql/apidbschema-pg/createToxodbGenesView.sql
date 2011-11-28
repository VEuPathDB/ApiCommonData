
CREATE OR REPLACE VIEW apidb.ToxodbGenes AS
SELECT *
FROM dots.GeneFeature gf
WHERE gf.external_database_release_id IN
      (SELECT edr.external_database_release_id
       FROM sres.ExternalDatabaseRelease edr,
            sres.ExternalDatabase ed
       WHERE edr.external_database_id = ed.external_database_id
         AND ed.name in  ('Chromosome Map - David Sibley', 'Roos Lab T. gondii apicoplast'));

