Ontology Development Kit (ODK) repository creator
=================================================

Website: https://github.com/INCATools/ontology-development-kit

Download ODK
------------- 
	git clone https://github.com/INCATools/ontology-development-kit.git


Install and Start Docker
------------------------
Install Docker following the instructions posted on the website:
https://github.com/INCATools/ontology-development-kit


Create GitHub repo for an initial OBO Library ontology
------------------------------------------------------
Go to directory, ontology-development-kit and run command:
	./seed-via-docker.sh

It will provide interactive interface for you to provide information need to generate an initial repository.

Notes: For import terms from external ontologies, ODK will retrieve the external ontologies to newly created repository. When external ontologies quite large, it may cause problem. In addition, OntoFox is generally used for external ontology terms import. So, it may no need to specify the ontologies that will be reused.

Newly created GitHub repo
-------------------------
Can be found under 'ontology-development-kit/target' directory

Directories and files in the repo:
- CONTRIBUTING.md
	guideline of NTR and other issue tracker submission

- README.md
	template GitHub repo homepage, provide ontology versions information. At least, we need to add description of the ontology

- ontology_prefix.obo
	release version OBO format ontology

- ontology_prefix.owl
	release version OWL format ontology

- issue_template.md
	NTR issue tracker template, quite useful. But it would be nice to think whether we can link the issue template to the issue label. So, it will not always show NTR template for all different issues, like bug report.

- imports
	full version of external ontologies in OBO and OWL formats. Suggest not use.

- src
   - metadata
	- README.md
		readme file described a couple of OBO Foundry ontology setting files, ontology_prefix.md and ontology_prefix.yml.
	- ontology_prefix.md
	- ontology_prefix.yml
		These two files are initial files and will be stored and updated in the OBO Foundry repositories. 

   - patterns
	Files used to generate ontology terms using design patterns. Since no detailed descriptions, it is hard to reuse these files. There are other ontology development tools, such as robot, can add ontology terms following a design pattern, we can use those tools for pattern implementation.	

   - sparql
	Some SPARQL queries used to retrieve information or quality checking (name contains 'violation') of the ontology
	
	Ontology information queries
	----------------------------
	basic-report.sparql
	   List all classes with the definitions and database cross referenced terms
	* class-count-by-prefix.sparql
	   Report the numbers of classes in different OBO Foundry ontologies, counts can be used in release notes.
	edges.sparql
	   List classes and their associated logic axioms, including rdfs:subClassOf. Results are using entity IRIs, so they are not human readable. Current the query is not very useful for our projects.	   
	* obsoletes.sparql
	   List deprecated classes with replace_by and consider annotations when available.
	subsets-labeled.sparql
	   List classes that specified 
	synonyms.sparql
	   List classes with synonyms. The synonyms are using OBO annotations. So, it is not work for ontologies using IAO: alternative labels annotation to specify synonyms.
	terms.sparql
	   List all term IRIs in the ontology.
	xrefs.sparql
	   List classes which have database cross reference annotation property with the annotation property values.

	Ontology checking queries
	----------------------------
	def-lacks-xref-violation.sparql
	   List classes without database cross reference annotations. For most of ontologies we use, we don't need this checking
	equivalent-classes-violation.sparql
	   List any classes have equivalent classes in the ontology. Although it is not good practice to have two or more classes are equivalent, it can happen when multiple ontologies defined same entity.  
	nolabels-violation.sparql
	   List GO classes that are not be replaced and no label. Need to update if we want to run this checking.
	* obsolete-violation.sparql
	   List deprecated classes that labels not start with "obsolete" or asserted under some entities. They are consider as issues need to be fixed. 
	owldef-self-reference-violation.sparql
	   List classes that reference itself.
	owldef-violation.sparql
	   Todo query, not working now.
	* redundant-subClassOf-violation.sparql
	   Redundant hierarchy checking. Issues need to be fixed.
	* trailing-whitespace-violation.sparql
	   List terms that has whitespace at the beginning or the end of the string.
	xref-syntax-violation.sparql
	   List terms that has database cross reference annotation property which values are not in correct format.
	

*: Queries we can consider to add to our ontology repositories and run during release

   - ontology
	- README-editors.md
	   readme of files for the ontology development.
	   .sh files are used to invoke Makefile to run ontology checking and making release
	- ontology_name-edit.owl 
	   the development version of the ontology
	- Makefile
	   need to adjust to fit specific ontology
	- imports
	   directory contains all import OWL and OBO files with input files
	- reports
	   SPARQL query results generate during the release process
