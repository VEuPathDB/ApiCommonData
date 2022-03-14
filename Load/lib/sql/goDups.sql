
-- This SQL script removes duplicate GO terms from sres.OntologyTerm, after first
-- updating all references to them (where were identified by means of foreign-key
-- constraints) to point instead to the first OntologyTerm record for that GO ID
-- (that is, the record with the lowest ontology_term_id).

--------------------------------------------------------------------------------
prompt populating ancestor_term_id

update sres.OntologyTerm the_table
set ancestor_term_id
    = (select max(ancestor_term_id)
       from sres.OntologyTerm
       where source_id = the_table.source_id)
where source_id like 'GO\_%' escape '\'
  and ancestor_term_id is null;

--------------------------------------------------------------------------------
prompt dropping old GoOntologyMapping table

drop table apidb.GoOntologyMapping;

prompt creating GoOntologyMapping table

create table apidb.GoOntologyMapping as
with dups
     as (select source_id
         from sres.OntologyTerm
         where source_id
               in (select source_id
                   from sres.OntologyTerm
                   where source_id like 'GO\_%' escape '\'
                   group by source_id
                   having count(*) > 1)),
     originals
     as (select source_id, min(ontology_term_id) as ontology_term_id
         from sres.OntologyTerm
         where source_id in (select source_id from dups)
         group by source_id)
select ot.source_id,
       ot.ontology_term_id as later_ontology_term_id,
       orig.ontology_term_id as original_ontology_term_id
from sres.OntologyTerm ot, originals orig
where ot.source_id = orig.source_id
  and ot.ontology_term_id != orig.ontology_term_id;

--------------------------------------------------------------------------------
prompt updating sres.OntologyRelationship

update sres.OntologyRelationship orel
set object_term_id
    = (select original_ontology_term_id
       from apidb.GoOntologyMapping
       where later_ontology_term_id = orel.object_term_id)
where object_term_id
      in (select later_ontology_term_id from apidb.GoOntologyMapping);

update sres.OntologyRelationship orel
set subject_term_id
    = (select original_ontology_term_id
       from apidb.GoOntologyMapping
       where later_ontology_term_id = orel.subject_term_id)
where subject_term_id
      in (select later_ontology_term_id from apidb.GoOntologyMapping);

--------------------------------------------------------------------------------
prompt updating sres.OntologySynonym

update sres.OntologySynonym osyn
set ontology_term_id
    = (select original_ontology_term_id
       from apidb.GoOntologyMapping
       where later_ontology_term_id = osyn.ontology_term_id)
where ontology_term_id
      in (select later_ontology_term_id from apidb.GoOntologyMapping);

--------------------------------------------------------------------------------
prompt updating apidb.GoSubset

update apidb.GoSubset the_table
set ontology_term_id
    = (select original_ontology_term_id
       from apidb.GoOntologyMapping
       where later_ontology_term_id = the_table.ontology_term_id)
where ontology_term_id
      in (select later_ontology_term_id from apidb.GoOntologyMapping);

--------------------------------------------------------------------------------
prompt updating dots.GoAssociation

update dots.GoAssociation the_table
set go_term_id
    = (select original_ontology_term_id
       from apidb.GoOntologyMapping
       where later_ontology_term_id = the_table.go_term_id)
where go_term_id
      in (select later_ontology_term_id from apidb.GoOntologyMapping)
  -- update only one record (so as not to violate the uniqueness constraint)
  -- choose the oldest (lowest GUS ID) of the alternate-ID records that map
  --  to the original ID
  and go_association_id
      = (select min(ga.go_association_id)
         from dots.GoAssociation ga, apidb.GoOntologyMapping gom1,
              apidb.GoOntologyMapping gom2
         where ga.table_id = the_table.table_id
           and ga.row_id = the_table.row_id
           and ga.is_not = the_table.is_not
           and ga.go_term_id = gom1.later_ontology_term_id
           and the_table.go_term_id = gom2.later_ontology_term_id
           and gom1.original_ontology_term_id = gom2.original_ontology_term_id
        )
  -- do the update only if there isn't already such a record
  -- (so that the update won't violate the uniqueness constraint)
  and (select count(*)
       from dots.GoAssociation ga, apidb.GoOntologyMapping gom
         where ga.table_id = the_table.table_id
           and ga.row_id = the_table.row_id
           and is_not = the_table.is_not
           and gom.original_ontology_term_id = ga.go_term_id
           and gom.later_ontology_term_id = the_table.go_term_id
      )
      = 0;

--------------------------------------------------------------------------------
prompt deleting from dots.GoAssocInstEvidCode

delete from dots.GoAssocInstEvidCode
where go_association_instance_id
      in (select go_association_instance_id
          from dots.GoAssociationInstance
          where go_association_id
                in (select go_association_id
                    from dots.GoAssociation
                    where go_term_id
                          in (select later_ontology_term_id
                              from apidb.GoOntologyMapping)
         ));
--------------------------------------------------------------------------------
prompt deleting from dots.GoAssociationInstance

delete from dots.GoAssociationInstance
where go_association_id
      in (select go_association_id
          from dots.GoAssociation
          where go_term_id
                in (select later_ontology_term_id
                    from apidb.GoOntologyMapping)
         );

prompt deleting from dots.GoAssociation

delete from dots.GoAssociation
where go_term_id
      in (select later_ontology_term_id
          from apidb.GoOntologyMapping);

--------------------------------------------------------------------------------
prompt updating sres.OntologyTerm.ancetor_term_id

update sres.OntologyTerm the_table
set ancestor_term_id
    = (select original_ontology_term_id
       from apidb.GoOntologyMapping
       where later_ontology_term_id = the_table.ancestor_term_id)
where ancestor_term_id
      in (select later_ontology_term_id from apidb.GoOntologyMapping);

--------------------------------------------------------------------------------
prompt updating sres.PathwayRelationship

update sres.PathwayRelationship the_table
set relationship_type_id
    = (select original_ontology_term_id
       from apidb.GoOntologyMapping
       where later_ontology_term_id = the_table.relationship_type_id)
where relationship_type_id
      in (select later_ontology_term_id from apidb.GoOntologyMapping);

--------------------------------------------------------------------------------
prompt updating sres.PathwayNode

update sres.PathwayNode the_table
set pathway_node_type_id
    = (select original_ontology_term_id
       from apidb.GoOntologyMapping
       where later_ontology_term_id = the_table.pathway_node_type_id)
where pathway_node_type_id
      in (select later_ontology_term_id from apidb.GoOntologyMapping);
--------------------------------------------------------------------------------
prompt updating apidb.PhenotypeResult

update apidb.PhenotypeResult the_table
set phenotype_entity_term_id
    = (select original_ontology_term_id
       from apidb.GoOntologyMapping
       where later_ontology_term_id = the_table.phenotype_entity_term_id)
where phenotype_entity_term_id
      in (select later_ontology_term_id from apidb.GoOntologyMapping);
--------------------------------------------------------------------------------
prompt deleting from sres.OntologyTerm

delete from sres.OntologyTerm
where ontology_term_id
      in (select later_ontology_term_id
          from apidb.GoOntologyMapping);

prompt DONE

exit


