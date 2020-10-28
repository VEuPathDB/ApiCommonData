----------------------------------
Get common terms across multiple datasets
----------------------------------

# common terms in GEMS1 and MALED
robot query --use-graphs true --input ./harmonization/gems_maled.owl --query ./SPARQL/commonTerms.rq ./query_results/commonTerms_gems1_maled.csv

# common terms in VIDA and GEMS
robot query --use-graphs true --input ./harmonization/gems_vida.owl --query ./SPARQL/commonTerms.rq ./query_results/commonTerms_gems_vida.csv

# common terms across SCORE
robot query --use-graphs true --input ./harmonization/score.owl --query ./SPARQL/commonTerms.rq ./query_results/commonTerms_score.csv


----------------------------------
OWL files used for common terms query
----------------------------------

The OWL files used for common terms query are available under:
ApiCommonData/Load/ontology/harmonization


----------------------------------
- gems_maled.owl
	gates_gems.owl
	gates_maled_phase3.owl


----------------------------------
- gems_vida.owl
	gems_merged.owl
	vida_merged.owl

Two merged files are generated using following robot commands:

# generate gems_merged.owl
robot merge --input ./harmonization/gems.owl annotate --ontology-iri http://purl.obolibrary.org/obo/gems_merged.owl --output ./harmonization/gems_merged.owl

# generate vida_merged.owl
robot merge --input ./harmonization/vida.owl annotate --ontology-iri http://purl.obolibrary.org/obo/vida_merged.owl --output ./harmonization/vida_merged.owl

----------------------------------
- score.owl
	gates_scoreBurundi.owl
	gates_scoreCrosssect.owl
	gates_scoreFiveCountry.owl
	gates_scoreMoz.owl
	gates_scoreNig.owl
	gates_scoreRwanda.owl
	gates_scoreSeasonal.owl
	gates_scoreSmCohort.owl
	gates_scoreZanzibar.owl