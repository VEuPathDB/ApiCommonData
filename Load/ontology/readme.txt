Ontology Directory
==============

conversionUpdate directory:
	- replace_EDA.csv
	- message.txt
	
	The file, replace_EDA.csv, is used as the input file for conversion file update script. It contains the term IRIs and the corresponding annotation properties associated with the terms that need to be updated in the conversion files. The headers should be same (not case sensitive) as what we used in the conversion file. If we want to update the IRI, it should be added using 'new IRI' as the column header.
	
	The file, 'message.txt', contains the output of the conversion update script, indicating the row and term IRI changes in a conversion file and the updated conversion file. 
	
Notes: The updated conversion file will be saved in the same directory as the conversion file with name xxx_conversion_temp.csv.	
	
------------------------------

Projects / datasets:
	- Gates
	- General
	- ICEMR
	- Microbiome

Each project/dataset has one folder, contains:
	OWL file: dataset display terminology
	‘doc’ directory: data dictionary and following documents to ontology mappings.

Files under ‘doc’ directory:
	- The filename of initial metadata file generated from data providers’ data dictionary: projectName_variables.xlsx
	- The filename of intermediate metadata file as: projectName_terms.xlsx
	- The filename of final metadata file for data loading as: projectName_ontology_mapping.xlsx (including column name to ontology term mapping)


Details of files:
===========

|— Gates
	|— doc: documents applied to both GEMS and MAL-ED data sets. Current contains data dictionary from HBGD.
	|— GEMS
		|— doc: GEMS related documents
		- gates_gems.owl
	|— MALED
		|— doc: MAL-ED related documents
		- gates_maled.owl
	- gates.owl: gates variables based on HBGD data dictionary, it contains variables for MAL-ED, GEMS1, and GEMS1A datasets. Current clinEpi ’MAL-ED’ dataset using it for search filters.
	
|— ICEMR
	|— amazonia: documents and ontology for ICEMR amazonia dataset
	|— india: documents and ontology for ICEMR india dataset
	|— prism: documents and ontology for ICEMR prism dataset
	|— category: category level terms for amazonia, india, and prism datasets
	|— archive-doc: old documents for ICEMR datasets
	|— protein_array: documents and ontology for protein array datasets (current we have 3 datasets, one dataset is from 8 ICEMR centers)
	|— doc: ICEMR related documents

|— Microbiome
	|— doc: 
		|— MIxS_standard: MixS standards
		- microbiome_terms.xlsx: 
		- microbiome_values.xlsx: value mapping
	- microbiome.owl

|— harmonization
	- ClinEpi_metadata.xlsx: file to hold the terms from different projects that mapped to same ontology term but with different display labels
	- harmonization_20170920.xlsx: harmonization issue solved on Sept 20, 2017

|— release: release version of EuPath ontology and display terminologies
	|— production: release versions of clinEpi terminologies
	|— 20140815: release made on Aug 15, 2014
	. . .
	|— 20171004: release made on Oct 4, 2017
	|- development: EuPath ontology and display terminologies that used to load in EuPath database
