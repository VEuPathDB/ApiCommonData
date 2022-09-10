conversionFileUpdater.jar
-----------------------------------------
Updated clinEpi conversion files according to given updated information based on term IRIs


-----------------------------------------
Run OntologyTermAnnotation.jar
-----------------------------------------
Requirement:
Java 1.8 and up

Command:
java -jar file_path/conversionFileUpdater.jar \
  -path conversion_file_directory/ \
  -input file_path/replace_input_filename \
  -messageFilename file_path/output_message_filename
  -overwrite true/false

-path: 
	directory that contains the conversion files (the filename contains 'conversion.csv') for updating 

-input: 
	filename including full_path/relative_path that contains the term IRI with associated updating information. The input files should be in 'csv' format and must start with IRI column because updating based on the term IRI used in the conversion file. The line starts with '#' considering as comment and will be ignored. The column header starts with '#' indicating the whole column will be ignored.

-messageFilename: 
	filename including full_path/relative_path used to write the detailed message regarding conversion file updates  

-overwrite: 
	specify whether overwrite the existing conversion file, when use 'true', it will overwrite the conversion file, otherwise, the updated conversion file will be written in the conversion_temp file

Example Command, run under ApiCommonData/Load/ontology directory:
java -jar script/conversionUpdate/conversionFileUpdater.jar \
  -path General/ \
  -input script/conversionUpdate/replace_IRI.csv \
  -messageFilename script/conversionUpdate/message.txt \
  -overwrite true

java -jar script/conversionUpdate/conversionFileUpdater.jar \
  -path Gates/ \
  -input script/conversionUpdate/replace_IRI.csv \
  -messageFilename script/conversionUpdate/message.txt \
  -overwrite true

java -jar script/conversionUpdate/conversionFileUpdater.jar \
  -path ICEMR/ \
  -input script/conversionUpdate/replace_IRI.csv \
  -messageFilename script/conversionUpdate/message.txt \
  -overwrite true



