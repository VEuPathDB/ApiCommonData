-- Toxo Apicoplast sequence is loaded in ExternalNASequence table,
-- but needs to be in the Virtual Sequence table

update dots.NASequenceImp
set    subclass_view = 'VirtualSequence'
where  na_sequence_id in (
  select na_sequence_id  
  from   dots.ExternalNASequence ena, sres.ExternalDatabase ed, sres.ExternalDatabaseRelease edr
  where  ena.external_database_release_id = edr.external_database_release_id
  and    edr.external_database_id = ed.external_database_id
  and    ed.name='Roos Lab T. gondii apicoplast'
  ) ;

-- source_id column are different for ExternalNASequence and VirtualSequence
update dots.VirtualSequence 
set    source_id = 'NC_001799', confidence = '' 
where  na_sequence_id in (
  select na_sequence_id  
  from   dots.VirtualSequence ena, sres.ExternalDatabase ed, sres.ExternalDatabaseRelease edr
  where  ena.external_database_release_id = edr.external_database_release_id
  and    edr.external_database_id = ed.external_database_id
  and    ed.name='Roos Lab T. gondii apicoplast'
  );
