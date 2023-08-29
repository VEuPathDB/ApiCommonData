DROP TABLE apidb.GeneFeatureProduct;

DROP SEQUENCE apidb.GeneFeatureProduct_sq;

DELETE FROM core.TableInfo
WHERE lower(name) =  'genefeatureproduct'
  AND database_id IN (SELECT database_id
                      FROM core.DatabaseInfo
                      WHERE lower(name) = 'apidb');

exit;
