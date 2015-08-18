package ApiCommonData::Load::AntibodyMicroarrayAnalysis;
use base qw(CBIL::TranscriptExpression::DataMunger::NoSampleConfigurationProfiles);

sub getProtocol {
  return "HostResponse";
}

1;

