DROP TABLE hmdb.chemical_data;
DROP TABLE hmdb.database_accession;
DROP TABLE hmdb.names;
DROP TABLE hmdb.default_structures;
DROP TABLE hmdb.autogen_structures;
DROP TABLE hmdb.structures;
DROP TABLE hmdb.compounds;

DROP SEQUENCE hmdb.chemical_data_SQ;
DROP SEQUENCE hmdb.compounds_SQ;
DROP SEQUENCE hmdb.database_accession_SQ;
DROP SEQUENCE hmdb.names_SQ;
DROP SEQUENCE hmdb.structures_SQ;
DROP SEQUENCE hmdb.default_structures_SQ;
DROP SEQUENCE hmdb.autogen_structures_SQ;

DELETE FROM core.TableInfo
WHERE lower (name) in ('chemical_data', 'compounds', 'database_accession', 'names', 'structures', 'default_structures', 'autogen_structures')
  AND database_id = (SELECT database_id
                     FROM core.DatabaseInfo
                     WHERE lower(name) = 'hmdb');

exit;
