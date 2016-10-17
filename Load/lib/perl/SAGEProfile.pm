package ApiCommonData::Load::SAGEProfile;
use base qw(CBIL::TranscriptExpression::DataMunger::NoSampleConfigurationProfiles);

sub getProtocolName {
  return "SAGE";
}

1;
