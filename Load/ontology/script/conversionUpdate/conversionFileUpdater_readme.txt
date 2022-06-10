conversionFileUpdater.jar
-----------------------------------------
Updated clinEpi conversion files according to given updated information based on term IRIs


-----------------------------------------
Run OntologyTermAnnotation.jar
-----------------------------------------
Requirement:
Java 1.8 and up

Example Command:
java -jar conversionFileUpdater.jar \
  -path /_PATH_/ApiCommonData/Load/ontology/Gates/ \
  -input /_PATH_/ApiCommonData/Load/ontology/conversionUpdate/replace_EDA.csv \
  -messageFilename /_PATH_/ApiCommonData/Load/ontology/conversionUpdate/message.txt

-path: directory that contains the files for updating
-input: filename including full path that contains the term ID with associated updating information  
-messageFilename: filename including full path used to write the update message regarding conversion file updates          
