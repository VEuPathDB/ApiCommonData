Created 2023-09-26

Ontology terms are loaded and used in many ways. Here are some useful queries.

==========================
variable_terms_from_db.csv
==========================

This query renders only terms used as variables (not categories), with the entity type "Category" as it is used in conversion/owl to denote entity type (Household, Participant, etc). There is no distinction between non-repeated or repeated measures.

    WITH attmap AS (
      SELECT t.STUDY_ID, initcap(regexp_replace(t.NAME, '.*repeated.*measure', '')) category, a.STABLE_ID, 'yes' repeated 
      FROM eda.ENTITYTYPE t LEFT JOIN eda."ATTRIBUTE" a ON t.ENTITY_TYPE_ID = a.entity_type_id
      WHERE t.ROW_PROJECT_ID =2
      AND lower(t.name) LIKE '%repeat%'
      UNION 
      SELECT t.STUDY_ID, initcap(t.NAME) category, a.STABLE_ID, '' repeated 
      FROM eda.ENTITYTYPE t LEFT JOIN eda."ATTRIBUTE" a ON t.ENTITY_TYPE_ID = a.entity_type_id
      WHERE t.ROW_PROJECT_ID =2
      AND lower(t.name) NOT LIKE '%repeat%'
      )
    SELECT DISTINCT 'http://purl.obolibrary.org/obo/' || a.STABLE_ID STABLE_ID, a.DISPLAY_NAME label, a.DEFINITION,
    'http://purl.obolibrary.org/obo/' || a.PARENT_STABLE_ID PARENT_STABLE_ID, b.DISPLAY_NAME parent_label,
    attmap.category category
      FROM eda.ATTRIBUTEGRAPH a, eda.ATTRIBUTEGRAPH b,
      attmap
      WHERE a.PARENT_ONTOLOGY_TERM_ID = b.ONTOLOGY_TERM_ID 
      AND a.STUDY_ID = b.STUDY_ID
      AND a.study_id = attmap.study_id
      AND a.STABLE_ID = attmap.stable_id
      AND a.ROW_PROJECT_ID =2
      AND attmap.category IS NOT NULL 
    ORDER BY attmap.category, a.display_name;
  

==========================
END
