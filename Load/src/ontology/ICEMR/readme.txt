Terminology used for ICEMR project
-------------------------------------

Organizational terms
- All ICEMR groups will use same hierarchy, all these organizational terms with ICEMR domain IDs

Data dictionary
- All data dictionary terms are added as leaf classes  
- All these terms should have mapped ontology terms 
- If no mapped ontology term found for any data dictionary, we will generate internal temporary terms with TEMP domain IDs. 

Controlled vocabulary of data dictionary
- The controlled vocabulary are added as individuals
- All these terms will map to ontology terms as many as possible.
- Some terms may be mapped to an ontology term in more broad meaning, this ontology term will be added as related synonym
- If no mapped ontology term found for any controlled vocabulary, we will generate internal temporary terms with TEMP domain IDs.

The mapping between Data dictionary and Controlled vocabulary to ontology terms should be one to one. 

Temporary terms
	The temporary terms will only have label and ID. Meanwhile, contact corresponding ontologies or prepare to add them in the EuPath ontology. The temporary terms will be deprecated when the terms are available in the ontology. Based on the need, we can decide whether we deprecate the temperoray terms following OBO Foundry/OBI deprecation policy


ICEMR terminology loading files
-------------------------------------

1. term file, list all terms in the ICEMR terminology including following content:
    a. term ID (ontology ID)
    b. ontological label
    c. ontological definition
    d. display definition (community preferred definition/description of term)
    e. term URI
    f. term type (indicate whether it is used in term organization or in data dictionary)
    g. ontology version
2. is_a relation file
    a. term ID
    b. relation: subClassOf
    c. parent term ID
3. mapping file
    a. term ID
    b. Data dictionary variable ID
    c. Data dictionary version
4. synonym file
     a. term ID
     b. preferred label 