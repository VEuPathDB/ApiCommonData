package ApiCommonData::Load::MRNADecayAnalysis;
use base qw(CBIL::StudyAssayResults::DataMunger::NoSampleConfigurationProfiles);

sub getProtocolName {
  return "MRNADecay";
}

1;

