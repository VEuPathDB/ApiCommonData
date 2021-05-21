drop user CORE cascade;
drop user COREVER cascade;
drop user DOTS cascade;
drop user DOTSVER cascade;
drop user MODEL cascade;
drop user MODELVER cascade;
drop user PLATFORM cascade;
drop user PLATFORMVER cascade;
drop user RESULTS cascade;
drop user RESULTSVER cascade;
drop user SRES cascade;
drop user SRESVER cascade;
drop user STUDY cascade;
drop user STUDYVER cascade;

-- drop CHEBI tables (but not schema):
alter table apidb.CompoundPeaksChebi drop foreign key fk_cpdpks_cid;
alter table results.CompoundMassSpec drop foreign key fk_cpdms_cid;

drop table chebi.database_accession;
drop table chebi.chemical_data;
drop table chebi.names;
drop table chebi.comments;
drop table chebi.ontology;
drop table chebi.vertice;
drop table chebi.relation;
drop table chebi.reference;
drop table chebi.structures;
drop table chebi.default_structures;
drop table chebi.autogen_structures;
drop table chebi.compounds;

exit
