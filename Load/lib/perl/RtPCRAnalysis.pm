package ApiCommonData::Load::RtPCRAnalysis;
use base qw(CBIL::StudyAssayResults::DataMunger::NoSampleConfigurationProfiles);

sub getProtocolName {
  return "rtpcr";
}

1;
