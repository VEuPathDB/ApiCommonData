package ApiCommonData::Load::OntologyTermResults;
use base qw(CBIL::StudyAssayResults::DataMunger::NoSampleConfigurationProfiles);

sub getProtocolName {
  return "simple_ontology_term_results";
}

1;

