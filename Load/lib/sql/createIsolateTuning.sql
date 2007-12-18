DROP MATERIALIZED VIEW apidb.IsolateAttributes; 
DROP INDEX apidb.IsolateAttr_sourceId_idx;

CREATE MATERIALIZED VIEW apidb.IsolateAttributes AS 
(
SELECT etn.na_sequence_id, 
       etn.external_database_release_id,
       etn.source_id,
       src.organism as organism,
			 src.strain || ' ' || src.isolate as strain,
			 src.specific_host || src.lab_host specific_host,
			 src.isolation_source,
			 src.country,
			 src.note,
			 etn.description,
			 src.pcr_primers,
			 etn.sequence,
			 aln.query_name,
			 aln.target_name,
			 aln.min_subject_start,
			 aln.max_subject_end,
			 aln.map,
			 'CryptoDB' as project_id
FROM   DoTS.ExternalNASequence etn,
			 DoTS.IsolateSource src,
			 SRes.ExternalDatabaseRelease edr,
			 SRes.ExternalDatabase edb, 
       ( SELECT extq.source_id,
			          extq.source_id query_name,
			          extt.source_id target_name,
							  sim.min_subject_start - 1500 as min_subject_start,
								sim.max_subject_end + 1500 as max_subject_end,
								extt.source_id || ':' || sim.min_subject_start || '..' || sim.max_subject_end as map
				 FROM   dots.SIMILARITY sim,
								dots.EXTERNALNASEQUENCE extt,
								dots.EXTERNALNASEQUENCE extq,
								SRes.ExternalDatabaseRelease edr,
								SRes.ExternalDatabase edb
				 WHERE  edr.external_database_id = edb.external_database_id 
				    AND edr.external_database_release_id = extq.external_database_release_id 
						AND edb.name = 'Isolates Data Test9' 
						AND edr.version = '2007-12-10' 
						AND sim.query_id = extq.na_sequence_id 
						AND sim.subject_id = extt.na_sequence_id) aln 
WHERE  aln.source_id(+) = etn.source_id  and 
       etn.na_sequence_id = src.na_sequence_id
			 AND edr.external_database_id = edb.external_database_id
			 AND edr.external_database_release_id = etn.external_database_release_id
			 AND edb.name = 'Isolates Data Test9'
			 AND edr.version = '2007-12-10'
);

CREATE INDEX apidb.IsolateAttr_sourceId_idx ON apidb.IsolateAttributes (source_id);

----------------------- Product Materialized View -------------------
DROP MATERIALIZED VIEW apidb.IsolateProductAttributes; 
DROP INDEX apidb.IsoProductAttr_idx;

CREATE MATERIALIZED VIEW apidb.IsolateProductAttributes AS 
(
SELECT etn.source_id,
			 'CryptoDB' as project_id,
       apidb.tab_to_string(cast(collect(gf.product) as apidb.varchartab), ' | ') as product
FROM   DoTS.ExternalNASequence etn,
			 DoTS.Genefeature gf,
			 SRes.ExternalDatabaseRelease edr,
			 SRes.ExternalDatabase edb
WHERE  etn.na_sequence_id = gf.na_sequence_id
	 AND edr.external_database_id = edb.external_database_id
	 AND edr.external_database_release_id = etn.external_database_release_id
	 AND edb.name = 'Isolates Data Test9'
	 AND edr.version = '2007-12-10'
GROUP BY etn.source_id
UNION
SELECT etn.source_id,
       'CryptoDB' as project_id,
			 dbms_lob.substr(com.comment_string, 4000, 1) as product 
FROM   DoTS.Repeats rpt,
       DoTS.externalnasequence etn,
       DoTS.nafeaturecomment com,
       SRes.ExternalDatabaseRelease edr,
       SRes.ExternalDatabase edb
Where  rpt.na_sequence_id = etn.na_sequence_id
   AND com.na_feature_id = rpt.na_feature_id
   AND edr.external_database_id = edb.external_database_id
   AND edr.external_database_release_id = rpt.external_database_release_id
   AND edb.name = 'Isolates Data Test9'
   AND edr.version = '2007-12-10'
);

CREATE INDEX apidb.IsoProductAttr_idx ON apidb.IsolateProductAttributes (source_id);
