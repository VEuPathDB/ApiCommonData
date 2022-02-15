OWLquery.jar
-----------------------------------------
Based on a term IRI to retrieve its label, category, parent term IRI, and parent term Label


-----------------------------------------
OWLquery.jar
-----------------------------------------
Requirement:
Java 1.8 and up

Command:
java -jar file_path/OWLquery.jar \
	-termListFile file_path/termListFilename \
	-ontologyFile file_path/ontologyFilename \
	-outputFile file_path/outputFilename 


termListFile: a text format file contains a list of term IRIs
ontologyFile: an OWL file that used to find a given IRI's label, category, parent IRI, and parent label
outputFile: a text file that stores the labels, categories, parent IRIs, and parent labels for given IRIs

-----------------------------------------
Run OWLquery.jar
-----------------------------------------

Test files are under script/test directory 

Example commands can run under ApiCommonData/Load/ontology directory.

1. Generate merged ontology for clinEpi term search

robot merge --input ./harmonization/clinEpi_eda.owl annotate \
	--ontology-iri http://purl.obolibrary.org/obo/clinEpi_eda_merged.owl \
	--output ./script/test/clinEpi_eda_merged.owl

2. Query clinEpi_eda_merged.owl to get term label, category, and parent term 

java -jar script/OWLquery.jar \
	-termListFile script/test/termList.txt \
	-ontologyFile script/test/clinEpi_eda_merged.owl \
	-outputFile script/test/termParents.tsv

