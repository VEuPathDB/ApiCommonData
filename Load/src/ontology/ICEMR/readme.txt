Terminology used for ICEMR project
-------------------------------------

Organizational terms
- All ICEMR groups will use same hierarchy, all these organizational terms with ICEMR domain IDs

Data dictionary
- All data dictionary terms are added as leaf classes  
- All these terms should have mapped ontology terms 
- If no mapped ontology term found for any data dictionary, we will generate internal temporary terms with ICEMR domain IDs. 

Controlled vocabulary of data dictionary
- The controlled vocabulary are added as individuals
- All these terms will map to ontology terms as many as possible.
- Some terms may map to an ontology term in more broad meaning, this ontology term will be added as related synonym
- If no mapped ontology term found for any controlled vocabulary, we will generate internal temporary terms with ICEMR domain IDs.

Notes: 
- The mapping between Data dictionary and Controlled vocabulary to ontology terms should be one to one. If more than one controlled vocabulary mapped to one ontology term, the ontology term will be addes as related 'Related Synonym', the controlled vocabulary may have same label in this case. 
- It is not necessary make all controlled vacabulary available in ontologies. But it is crucial to use Controlled vocabulary consistently across multiple ICEMR projects.

Temporary terms
	The temporary terms will only have label and ID. Meanwhile, contact corresponding ontologies or prepare to add them in the EuPath ontology. The temporary terms will be deprecated when the terms are available in the ontology. Based on the need, we can decide whether we deprecate the temporary terms following OBO Foundry/OBI deprecation policy.


ICEMR terminology temporary ontology term ID
--------------------------------------------
temporary ID will be assigned with domain ‘ICEMR’
- category:		00000xx	(next available ICEMR_0000005-)
- PRISM range: 		variables: 0100000 - 0101000	values: 1000000 - 1001000
- Indian range: 	variables: 0101001 - 0102000	values: 1001001 - 1002000
- Amazonia range: 	variables: 0102001 - 0103000	values: 1002001 - 1003000

ICEMR terminology for data loading and rule for assigning data dictionary IDs
--------------------------------------------
Term file for data loading including three term types, category, variables and values
- ontology ID
- display label
- parent ontology ID
- parent display label
- data dictionary ID (http://purl.obolibrary.org/obo/eupath/icemr.owl#PROJECTname_id)
	PROJECTname + “_” + 7 digits
	. for category:   0000xxx
	. for variable:   0100xxx
	. for individual: 1000xxx
- data dictionary label (should be column name) 
- term type: category, variable, or value

Rules for converting term IRI to term IDs for terms in SNOMEDCT and MEDDRA
--------------------------------------------
http://purl.bioontology.org/ontology/SNOMEDCT/40541001
-> ID SNOMEDCT_40541001
http://purl.bioontology.org/ontology/MEDDRA/10015958
-> ID MEDDRA_10015958


ICEMR project Ontology URIs:
--------------------------------------------
- category
http://purl.obolibrary.org/obo/eupath/icemr/PROJECTname_category.owl
- variables
http://purl.obolibrary.org/obo/eupath/icemr/PROJECTname_variables.owl
- values
http://purl.obolibrary.org/obo/eupath/icemr/PROJECTname_values.owl
- annotation
http://purl.obolibrary.org/obo/eupath/icemr/annotation.owl

- merged file
http://purl.obolibrary.org/obo/eupath/icemr/icemr_PROJECTname.owl


ICEMR terminology loading files
-------------------------------------
1. term file, list all terms in the ICEMR terminology including following content:
    a. term ID (ontology ID)
    b. ontological label
    c. display definition (community preferred definition/description of term)
    d. term URI
    e. term type (indicate whether it is used in term organization or in data dictionary)
    f. ontology version

2. relation file
    a. term ID
    b. relation: subClassOf and synonymOf
    c. parent term ID

3. mapping file
    a. term ID
    b. Data dictionary variable ID
    c. Data dictionary version


Current PRISM terminology files in the server:
/eupath/data/EuPathDB/manualDelivery/PRISM/common/ontology/ICEMR_PRISM/20151118/final/ 




     