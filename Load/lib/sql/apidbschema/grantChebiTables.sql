GRANT INSERT, SELECT, UPDATE, DELETE ON chebi.compounds  TO gus_w;
GRANT SELECT ON chebi.compounds  TO gus_r;

GRANT INSERT, SELECT, UPDATE, DELETE ON chebi.database_accession  TO gus_w;
GRANT SELECT ON chebi.database_accession TO gus_r;

GRANT INSERT, SELECT, UPDATE, DELETE ON chebi.chemical_data TO gus_w;
GRANT SELECT ON chebi.chemical_data TO gus_r;

GRANT INSERT, SELECT, UPDATE, DELETE ON chebi.names TO gus_w;
GRANT SELECT ON chebi.names TO gus_r;

GRANT INSERT, SELECT, UPDATE, DELETE ON chebi.comments TO gus_w;
GRANT SELECT ON chebi.comments TO gus_r;

GRANT INSERT, SELECT, UPDATE, DELETE ON chebi.ontology TO gus_w;
GRANT SELECT ON chebi.ontology TO gus_r;

GRANT INSERT, SELECT, UPDATE, DELETE ON chebi.vertice TO gus_w;
GRANT SELECT ON chebi.vertice TO gus_r;

GRANT INSERT, SELECT, UPDATE, DELETE ON chebi.relation TO gus_w;
GRANT SELECT ON chebi.relation TO gus_r;

GRANT INSERT, SELECT, UPDATE, DELETE ON chebi.reference TO gus_w;
GRANT SELECT ON chebi.reference TO gus_r;

GRANT INSERT, SELECT, UPDATE, DELETE ON chebi.default_structures TO gus_w;
GRANT SELECT ON chebi.default_structures TO gus_r;

GRANT INSERT, SELECT, UPDATE, DELETE ON chebi.autogen_structures TO gus_w;
GRANT SELECT ON chebi.autogen_structures TO gus_r;

exit;
