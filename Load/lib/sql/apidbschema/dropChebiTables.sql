

Drop table chebi.database_accession;

Drop table chebi.chemical_data;

Drop table chebi.names;

Drop table chebi.comments;

Drop table chebi.ontology;

Drop table chebi.vertice;

Drop table chebi.relation;

Drop table chebi.reference;

Drop table chebi.structures;

Drop table chebi.default_structures;

Drop table chebi.autogen_structures;

Drop table chebi.compounds;

-- this foreign key must be added here because the chebi schema install is done later than other installs
alter table Results.CompoundMassSpec drop foreign key fk_cpdms_cid;

delete core.tableinfo where database_id in (select database_id from core.databaseinfo where name = 'chEBI')

exit;
