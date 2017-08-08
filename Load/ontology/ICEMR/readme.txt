
will work on it
===============

Requirements of ICEMR data submission

Following information associated with ICEMR data are need to be submitted with the data.

1. Data dictionary used by the data

The data dictionary should include variable name, description, preferred name for display on PlasmoDB if any (optional), and the controlled vocabulary used for the variable.

If the data dictionary in language other than English, please provide all the required information in English as well.

Here are two examples:
- age
	name: age
	description: age of participant when he/she at enrollment
	display name: age at enrollment
	value: number in year
- roof material
	name: MMROOF
	description:Main material of the roof.
	display name: roof material  
	value: thatched, mud, wood, iron sheets, tin, other

2. Column names of the data set
	List all column names used in the submitted data

3. Mapping of column names to the data dictionary
	List the column name used corresponding to the data dictionary variables or values

Here are two examples:
- age
	variable in data dictionary: age
	column name: age_en
- symptom
	variable in data dictionary: symptom
	value of ‘symptom’: abdomen pain, fever, …
	column name: abdomen pain, fever, … 	

4. Mapping of values used in the data to data dictionary variable controlled vocabulary

For examples, the controlled vacabulary of roof material are thatched, mud, wood, iron sheets, tin, other. The values used in the data are 1 - 7. The mapping is:
	thatched	1
	mud		2
	wood		3
	iron		4
	sheets		5
	tin		6
	other		7




——————————————
2. We need to know 
- how column names mapped to data dictionary (could be variable could be controlled vocabulary)
in the data corresponding to dictionary variables
and the values of variables for controlled vocabulary of data dictionary variables


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
- The mapping between Data dictionary and Controlled vocabulary to ontology terms should be one to one. If more than one controlled vocabulary mapped to one ontology term, the ontology term will be added as related 'Related Synonym', the controlled vocabulary may have same label in this case. 
- It is not necessary make all controlled vocabulary available in ontologies. But it is crucial to use Controlled vocabulary consistently across multiple ICEMR projects.

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




     