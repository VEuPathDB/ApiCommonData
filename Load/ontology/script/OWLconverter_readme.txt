OWLconverter.jar
-----------------------------------------
Convert tab delimited or csv file to OWL format file


-----------------------------------------
Run OWLconverter.jar
-----------------------------------------
Requirement:
Java 1.7 and up

Command:
java -jar file_path/OWLconverter.jar -settingFilename file_path/setting_filename 

======================
Test files
====================== 
Under test directory 

Example:
java -jar OWLconverter.jar -settingFilename test/setting.txt 
java -jar OWLconverter.jar -settingFilename test/setting2.txt 
java -jar OWLconverter.jar -settingFilename test/setting3.txt 

Notes: please update path to your script/test directory in the setting.txt before run the command.

-----------------------------------------
Preparation of Setting file
-----------------------------------------
Setting file is a tab-delimited text file, contains 2 columns specified the information needed to convert a tab-delimited or csv format file to OWL file. The first columns are parameters taken by the script and should be not be renamed. The second columns are values of parameters. 

path (required)
	the path to the input text file for conversion and the converted OWL file for saving 

input file (required)
	name of tab-delimited or csv file used for conversion

output file (required)
	name of converted OWL file
	
ontology IRI (required)
	the ontology IRI of converted OWL file

IRI base (required)
	xml:base URI of the ontology
prefix (required)
	the prefix of ID used for newly generated ontology terms
start ID (required)	
	start ID number of newly generated ontology terms, it will be 

external ontology file (optional)
	external ontology used to find the ontology term IRI based on labels
	term position (required) 
	column number that contains the term labels that will be added in the OWL file. The term labels must be provided in the conversion input file.

term IRI position (required)
	column number that contains the term labels that will be added in the OWL file.
The term IRIs can be empty in the conversion input file. The script can get term IRI based on the labels from the external ontology or create by given URI base, prefix, and start ID parameters if the term IRI is not available.
term parent position (required)
	column number that contains the term parent labels that will be added in the OWL file. The term parent can be empty in the conversion input file.

term parent IRI position (required)
	column number that contains the term parent labels that will be added in the OWL file. The term parent can be empty in the conversion input file. When the parent IRI is not set in the conversion input file, it will be asserted under owl:Thing. 
	annotation property (optional)
	the annotations of the ontology terms. The labels of annotation properties should be used as the column headers in the conversion input file. If we'd like to specify IRI or ID of the annotationProperty in the setting file, it can be appended after the corresponding column header and separate by '|'. When ID provided, "http://purl.obolibrary.org/obo/" URI base will be used. If annotation property IRI is not available, it will be created by given URI base, prefix, and start ID parameters.

======================
Setting file template
======================
path	input file	output file	ontology IRI	
IRI base	prefix	start ID	external ontology file	term position	term IRI position		term parent position		term parent IRI position		annotation property	

