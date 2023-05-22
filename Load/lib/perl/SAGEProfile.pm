package ApiCommonData::Load::SAGEProfile;
use base qw(CBIL::StudyAssayResults::DataMunger::NoSampleConfigurationProfiles);

sub getProtocolName {
  return "SAGE";
}

1;
