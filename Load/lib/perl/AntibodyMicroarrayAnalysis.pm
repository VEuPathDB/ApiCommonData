package ApiCommonData::Load::AntibodyMicroarrayAnalysis;
use base qw(CBIL::StudyAssayResults::DataMunger::NoSampleConfigurationProfiles);

sub getProtocolName {
  return "Antibody Microarray";
}

sub getTechnologyType {
  return "protein_microarray";
}

1;

