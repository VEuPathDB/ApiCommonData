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

Ontology IRI (required)
	the ontology IRI for newly generated OWL file

IRI base (optional): IRI base for newly generated ontology terms
Prefix (optional): Prefix of ID for newly generated ontology terms
start ID (optional): start ID number for newly generated ontology terms	
	The values only needed when new ontology term (including both class and property) will be added in the OWL file

external ontology file (optional)
	external ontology used to find the ontology term IRI based on labels
		annotation property (optional)
	the annotations of the ontology terms. If we'd like to specify IRI or ID of the annotationProperty in the setting file, it can be appended after the corresponding column header used in the conversion file and separate by '|'. When ID provided, "http://purl.obolibrary.org/obo/" URI base will be used. If annotation property IRI is not available, it will be created by given URI base, prefix, and start ID parameters. In this case, 

Notes: If we don't provide any annotation property, the OWL file will only contain term label with is-a relation.


======================
Setting file template
======================
path	input file	output file	ontology IRI	
IRI base	prefix	start ID	external ontology file	annotation property	

