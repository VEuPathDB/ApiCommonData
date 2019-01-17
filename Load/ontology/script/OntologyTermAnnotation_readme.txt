OntologyTermAnnotation.jar
-----------------------------------------
add or edit annotation property values for terms in a give ontology


-----------------------------------------
Run OntologyTermAnnotation.jar
-----------------------------------------
Requirement:
Java 1.7 and up

Command:
java -jar OntologyTermAnnotation.jar -ontologyFilename file_path/ontology_filename -annotationFilename file_path/annotation_filename -outOntologyFilename file_path/out_ontology_filename 

-ontologyFilename: ontology filename including path, annotations of some entities in the ontology intend to be added/updated
-annotationFilename: Annotation values of specific annotation properties for give entities (need provide entity IRIs) listed in the file   
-outOntologyFilename: ontology filename including path, with updated annotation values          

======================
Test files
====================== 
Under test directory, ontology file, icemr_india_feverSurv.owl, annotation file, newOrders.txt

Example:
java -jar OntologyTermAnnotation.jar -ontologyFilename test/icemr_india_feverSurv.owl -annotationFilename test/newOrders.txt -outOntologyFilename test/icemr_india_feverSurv_new.owl

-----------------------------------------
Preparation of input annotation file
-----------------------------------------
The annotation file is a tab-delimited text file, which contains at least 2 columns specifying the ontology entity IRIs and annotation properties to be added or updated. 
The annotation properties are set on the column header(s). Either annotation property IRI or ID should be provided. If ID is provided, the IRI will be the standard OBO IRI, following the pattern http://purl.obolibrary.org/obo/ID. For other annotation properties, the annotation label and IRI can be provided (e.g. if 'display order|EUPATH_0000274' is provided in the header, the script will add the annotation property with the IRI http://purl.obolibrary.org/obo/EUPATH_0000274 and the label 'display order' in the updated ontology).
The first column should contain the IRIs of ontology entities, and the remaining columns should contain the values of annotation properties to be added or updated. 