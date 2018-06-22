DROP TABLE hmdb.chemical_data;
DROP TABLE hmdb.comments;
DROP TABLE hmdb.database_accession;
DROP TABLE hmdb.names;
DROP TABLE hmdb.reference;
DROP TABLE hmdb.relation;
DROP TABLE hmdb.default_structures;
DROP TABLE hmdb.autogen_structures;
DROP TABLE hmdb.structures;
DROP TABLE hmdb.vertice;
DROP TABLE hmdb.ontology;
DROP TABLE hmdb.compounds;

DROP SEQUENCE hmdb.chemical_data_SQ;
DROP SEQUENCE hmdb.comments_SQ;
DROP SEQUENCE hmdb.compounds_SQ;
DROP SEQUENCE hmdb.database_accession_SQ;
DROP SEQUENCE hmdb.names_SQ;
DROP SEQUENCE hmdb.ontology_SQ;
DROP SEQUENCE hmdb.reference_SQ;
DROP SEQUENCE hmdb.relation_SQ;
DROP SEQUENCE hmdb.vertice_SQ;
DROP SEQUENCE hmdb.structures_SQ;
DROP SEQUENCE hmdb.default_structures_SQ;
DROP SEQUENCE hmdb.autogen_structures_SQ;

DELETE FROM core.TableInfo
WHERE lower(name) in ('chemical_data', 'comments', 'compounds', 'database_accession', 'names', 'ontology', 'reference', 'relation', 'vertice', 'structures', 'default_structures', 'autogen_structures')
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo
                     WHERE lower(name) = 'hmdb');

exit;
