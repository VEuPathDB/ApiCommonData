-- 3-prime SAGE TAGS:

CREATE TABLE apidb.SageTags_3prime (
 na_feature_id        NUMBER(10),
 na_sequence_id      NUMBER(10),
 composite_element_id NUMBER(10),
 sp                   NUMBER(12),
 d4                   NUMBER(12),
 d6                   NUMBER(12),
 d7                   NUMBER(12),
 d17                  NUMBER(12),
 ph                   NUMBER(12),
 msj                  NUMBER(12),
 rh                   NUMBER(12),
 b7                   NUMBER(12),
 tag                  VARCHAR2(500),
 tag_count	      NUMBER(10),
 startm               NUMBER(12),
 end                  NUMBER(12),
 strand               NUMBER(3)
);

INSERT INTO apidb.SageTags_3prime
 (na_feature_id, na_sequence_id, composite_element_id, tag)
SELECT      distinct stf.na_feature_id, stf.na_sequence_id, 
            str.composite_element_id, st.tag
FROM        RAD.SageTag st, RAD.SageTagResult str, DoTS.SageTagFeature stf
WHERE       st.composite_element_id = str.composite_element_id
 AND	    st.composite_element_id = stf.source_id
 AND	    st.array_design_id IN (
  SELECT array_design_id 
  FROM RAD.ARRAYDESIGN 
  WHERE description = 'T. gondii 3p SAGE tags from M. White lab via A Mackey' );


--coordinates:
UPDATE 	apidb.SageTags_3prime stc
SET      startm = (
SELECT decode((l.is_reversed + sm.strand_orientation), 
                 2, (sm.startm + l.start_min), 
                 1, (sm.startm + l.start_min),
                -1, (sm.end - l.end_max +1),
                 0, (sm.end - l.end_max +1) )
FROM  dots.nalocation l, apidb.scaffold_map sm
WHERE l.na_feature_id = stc.na_feature_id   
  AND sm.piece_na_sequence_id = stc.na_sequence_id);

UPDATE 	apidb.SageTags_3prime stc
SET     end = (
SELECT decode((l.is_reversed + sm.strand_orientation), 
                 2, (sm.startm + l.start_min +13),
                 1, (sm.startm + l.end_max -1),
                -1, (sm.end - l.start_min),
                 0, (sm.end - l.start_min) )
FROM  dots.nalocation l, apidb.scaffold_map sm
WHERE l.na_feature_id = stc.na_feature_id   
  AND sm.piece_na_sequence_id = stc.na_sequence_id); 

UPDATE 	apidb.SageTags_3prime stc
SET     strand = (
(SELECT  decode((l.is_reversed + sm.strand_orientation), '-1', '+1', 0, '-1', 1, '+1', 2, '-1', '.')
 FROM  dots.nalocation l, apidb.scaffold_map sm
 WHERE l.na_feature_id = stc.na_feature_id   
   AND sm.piece_na_sequence_id = stc.na_sequence_id 
   AND sm.virtual_source_id NOT LIKE 'TGG_%' )
 UNION 
(SELECT  decode((l.is_reversed), 0, '+1', 1, '-1', '.')
 FROM  dots.nalocation l, apidb.scaffold_map sm
 WHERE l.na_feature_id = stc.na_feature_id   
   AND sm.piece_na_sequence_id = stc.na_sequence_id 
   AND sm.virtual_source_id LIKE 'TGG_%'));


--quantifications:
UPDATE 	apidb.SageTags_3prime stc
SET    	sp = (
SELECT 	str.tag_count
FROM   	RAD.SageTagResult str, RAD.Quantification q,
	DoTS.SageTagFeature stf
WHERE  	stc.na_feature_id = stf.na_feature_id
AND	str.composite_element_id = stf.source_id
AND    	str.quantification_id = q.quantification_id
AND    	q.name = 'sp'
);

UPDATE 	apidb.SageTags_3prime stc
SET    	d4 = (
SELECT 	str.tag_count
FROM   	RAD.SageTagResult str, RAD.Quantification q,
	DoTS.SageTagFeature stf
WHERE  	stc.na_feature_id = stf.na_feature_id
AND	str.composite_element_id = stf.source_id
AND    	str.quantification_id = q.quantification_id
AND    	q.name = 'd4'
);

UPDATE 	apidb.SageTags_3prime stc
SET    	d6 = (
SELECT 	str.tag_count
FROM   	RAD.SageTagResult str, RAD.Quantification q,
	DoTS.SageTagFeature stf
WHERE  	stc.na_feature_id = stf.na_feature_id
AND	str.composite_element_id = stf.source_id
AND    	str.quantification_id = q.quantification_id
AND    	q.name = 'd6'
);

UPDATE 	apidb.SageTags_3prime stc
SET    	d7 = (
SELECT 	str.tag_count
FROM   	RAD.SageTagResult str, RAD.Quantification q,
	DoTS.SageTagFeature stf
WHERE  	stc.na_feature_id = stf.na_feature_id
AND	str.composite_element_id = stf.source_id
AND    	str.quantification_id = q.quantification_id
AND    	q.name = 'd7'
);

UPDATE 	apidb.SageTags_3prime stc
SET    	d17 = (
SELECT 	str.tag_count
FROM   	RAD.SageTagResult str, RAD.Quantification q,
	DoTS.SageTagFeature stf
WHERE  	stc.na_feature_id = stf.na_feature_id
AND	str.composite_element_id = stf.source_id
AND    	str.quantification_id = q.quantification_id
AND    	q.name = 'd17'
);

UPDATE 	apidb.SageTags_3prime stc
SET    	ph = (
SELECT 	str.tag_count
FROM   	RAD.SageTagResult str, RAD.Quantification q,
	DoTS.SageTagFeature stf
WHERE  	stc.na_feature_id = stf.na_feature_id
AND	str.composite_element_id = stf.source_id
AND    	str.quantification_id = q.quantification_id
AND    	q.name = 'ph'
);

UPDATE 	apidb.SageTags_3prime stc
SET    	msj = (
SELECT 	str.tag_count
FROM   	RAD.SageTagResult str, RAD.Quantification q,
	DoTS.SageTagFeature stf
WHERE  	stc.na_feature_id = stf.na_feature_id
AND	str.composite_element_id = stf.source_id
AND    	str.quantification_id = q.quantification_id
AND    	q.name = 'msj'
);

UPDATE 	apidb.SageTags_3prime stc
SET    	rh = (
SELECT 	str.tag_count
FROM   	RAD.SageTagResult str, RAD.Quantification q,
	DoTS.SageTagFeature stf
WHERE  	stc.na_feature_id = stf.na_feature_id
AND	str.composite_element_id = stf.source_id
AND    	str.quantification_id = q.quantification_id
AND    	q.name = 'rh'
);

UPDATE 	apidb.SageTags_3prime stc
SET    	b7 = (
SELECT 	str.tag_count
FROM   	RAD.SageTagResult str, RAD.Quantification q,
	DoTS.SageTagFeature stf
WHERE  	stc.na_feature_id = stf.na_feature_id
AND	str.composite_element_id = stf.source_id
AND    	str.quantification_id = q.quantification_id
AND    	q.name like  'b7%'
);

--tag_count:
UPDATE apidb.SageTags_3prime stc
SET    	tag_count = (
SELECT 	count(*) 
FROM  	apidb.SageTags_3prime tmp
WHERE  	stc.tag = tmp.tag
);

--permissions
GRANT insert, select, update, delete ON apidb.SageTags_3prime to gus_w;
GRANT select ON apidb.SageTags_3prime TO gus_r;

----------------------------------------------------------------------

-- 5-prime SAGE TAGS:

CREATE TABLE apidb.SageTags_5prime (
 na_feature_id        NUMBER(10),
 na_sequence_id      NUMBER(10),
 composite_element_id NUMBER(10),
 tag                  VARCHAR2(500),
 tag_count	      NUMBER(10),
 startm               NUMBER(12),
 end                  NUMBER(12),
 strand               NUMBER(3)
);

INSERT INTO apidb.SageTags_5prime
 (na_feature_id, na_sequence_id, composite_element_id, tag)
SELECT      distinct stf.na_feature_id, stf.na_sequence_id, 
            st.composite_element_id, st.tag
FROM        RAD.SageTag st, DoTS.SageTagFeature stf
WHERE       st.composite_element_id = stf.source_id
 AND	    st.array_design_id IN (
  SELECT array_design_id 
  FROM RAD.ARRAYDESIGN 
  WHERE description = 'T. gondii 5p SAGE Tags from M. White lab via A Mackey')

--cordinates:
UPDATE 	apidb.SageTags_5prime stc
SET      startm = (
SELECT decode((l.is_reversed + sm.strand_orientation), 
                 2, (sm.startm + l.start_min), 
                 1, (sm.startm + l.start_min),
                -1, (sm.end - l.end_max +1),
                 0, (sm.end - l.end_max +1) )
FROM  dots.nalocation l, apidb.scaffold_map sm
WHERE l.na_feature_id = stc.na_feature_id   
  AND sm.piece_na_sequence_id = stc.na_sequence_id); 

UPDATE 	apidb.SageTags_5prime stc
SET     end = (
SELECT decode((l.is_reversed + sm.strand_orientation), 
                 2, (sm.startm + l.start_min +13),
                 1, (sm.startm + l.end_max -1),
                -1, (sm.end - l.start_min),
                 0, (sm.end - l.start_min) )
FROM  dots.nalocation l, apidb.scaffold_map sm
WHERE l.na_feature_id = stc.na_feature_id   
  AND sm.piece_na_sequence_id = stc.na_sequence_id); 

UPDATE 	apidb.SageTags_5prime stc
SET     strand = (
(SELECT  decode((l.is_reversed + sm.strand_orientation), '-1', '+1', 0, '-1', 1, '+1', 2, '-1', '.')
 FROM  dots.nalocation l, apidb.scaffold_map sm
 WHERE l.na_feature_id = stc.na_feature_id   
   AND sm.piece_na_sequence_id = stc.na_sequence_id 
   AND sm.virtual_source_id NOT LIKE 'TGG_%' )
 UNION 
(SELECT  decode((l.is_reversed), 0, '+1', 1, '-1', '.')
 FROM  dots.nalocation l, apidb.scaffold_map sm
 WHERE l.na_feature_id = stc.na_feature_id   
   AND sm.piece_na_sequence_id = stc.na_sequence_id 
   AND sm.virtual_source_id LIKE 'TGG_%'));

--tag_count:
UPDATE 	apidb.SageTags_5prime stc
SET    	tag_count = (
SELECT 	count(*) 
FROM  	apidb.SageTags_5prime tmp
WHERE  	stc.tag = tmp.tag
);

--permissions:
GRANT insert, select, update, delete ON apidb.SageTags_5prime to gus_w;
GRANT select ON apidb.SageTags_5prime TO gus_r;


exit;
