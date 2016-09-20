package ApiCommonData::Load::AntibodyMicroarrayAnalysis;
use base qw(CBIL::TranscriptExpression::DataMunger::NoSampleConfigurationProfiles);

sub getProtocolName {
  return "Antibody Microarray";
}

sub getTechnologyType {
  return "protein_microarray";
}

1;

