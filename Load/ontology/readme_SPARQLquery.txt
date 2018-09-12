# This file documented how we can run SPARQL queries using ROBOT tool to query and preform quality checking
# on EuPathDB terminologies in OWL format. Current we are focusing on ClinEpi projects.

=============================================================
# Install ROBOT
=============================================================
Please following the instruction on the page:
	http://robot.obolibrary.org

=============================================================
# Retrieve ontology files and SPARQL queries from SVN repository
=============================================================
SVN check out the files from https://cbilsvn.pmacs.upenn.edu/svn/apidb/ApiCommonData/trunk/Load/ontology and store under ontology directory
	svn co https://cbilsvn.pmacs.upenn.edu/svn/apidb/ApiCommonData/trunk/Load/ontology ontology/

# EuPathDB projects
. Genomics site
	- ISA-TAB files: eupath_isa.owl
	- ICEMR protein array: protein_array.owl

. Microbiome DB
	- microbiome.owl

. ClinEpi site
	- Gates
		gates_maled.owl
		gates_gems.owl
		gates_gems1a.owl
	- ICEMR
		icemr_prism.owl
		icemr_indian.owl
		icemr_southAsia.owl
		icemr_amazoniaPeru_long.owl

# SPARQL queries is under:
	ontology/SPARQL

# harmonization/web_display.owl
	includes all EuPathDB projects

# harmonization/clinEpi.owl
	includes all ClinEpi projects

# File organization under ontology is documented in the file:
	readme.rtf
(some information may out-of-date, need to be updated)

=============================================================
# Issue SPARQL queries using robot tools
=============================================================

1. Open Terminal window for running command line
How to open terminal on Mac? 
	https://www.wikihow.com/Open-a-Terminal-Window-in-Mac
How to open terminal on Window 10? 
	https://www.howtogeek.com/235101/10-ways-to-open-the-command-prompt-in-windows-10/

2. Change path to checked-out ontology directory

3. Create a directory ‘query_results’ under ontology for saving query results
	mkdir query_results

4. Following SPARQL queries can be ran using ROBOT tool, SPARQL queries are in SPARQL directory and query results will be saved in query_results directory. All output are in CSV format. We can set the output as other formats, like TSV, TTL, JSONLD, etc.

Notes: You need to change the PATH to the files or queries if you want to run the query and save results in the directory other than what specified here.

=============================================================
# Individual project queries
=============================================================

————————————————————————————————————————————————————————————
# Generate the file for adding/updating display order
#	get_column_sourceID_label_parent.rq
————————————————————————————————————————————————————————————
# ICEMR southAsia
robot query --input ./ICEMR/south_asia/icemr_southAsia.owl --query ./SPARQL/get_displayOrder_lable_parentLabel.rq ./query_results/ICEMR_southAsia_displayOrder.csv

# Gates MALED
robot query --input ./Gates/MALED/gates_maled.owl --query ./SPARQL/get_displayOrder_lable_parentLabel.rq ./query_results/gates_MALED_displayOrder.csv


=============================================================
# Multiple projects queries
=============================================================

————————————————————————————————————————————————————————————
# List all terms with their parents and project sources
#	get_termWithParentAndSource.rq
————————————————————————————————————————————————————————————
# ClinEpi
robot query --use-graphs true --input ./harmonization/clinEpi.owl --query ./SPARQL/get_termWithParentAndSource.rq ./query_results/clinEpi_termsWithParentAndSource.csv

————————————————————————————————————————————————————————————
# Find terms used in which project(s)
#	get_termWithSourceGroupByID.rq
————————————————————————————————————————————————————————————
# ClinEpi
robot query --use-graphs true --input ./harmonization/clinEpi.owl --query ./SPARQL/get_termWithSourceGroupByID.rq ./query_results/clinEpi_termsWithSource.csv

————————————————————————————————————————————————————————————
# Check any inconsistent labels used for same ontology term in multiple projects 
#	QC_termWithMultipleLabelsWithSource.rq
————————————————————————————————————————————————————————————
# ClinEpi
robot query --use-graphs true --input ./harmonization/clinEpi.owl --query ./SPARQL/QC_termWithMultipleLabelsWithSource.rq ./query_results/clinEpi_termWithMultipleLabelsWithSource.csv

————————————————————————————————————————————————————————————
# Retrieve terms which are not leaves of the tree (considering the terms as category), used to generate category OWL file  
#	get_nonLeaf_terms.rq
————————————————————————————————————————————————————————————
# ClinEpi projects
robot query --use-graphs true --input ./harmonization/clinEpi.owl --query ./SPARQL/get_nonLeaf_terms.rq ./query_results/clinEpi_categories.csv



