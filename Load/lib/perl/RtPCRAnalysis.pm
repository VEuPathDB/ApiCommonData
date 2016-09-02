package ApiCommonData::Load::RtPCRAnalysis;
use base qw(CBIL::TranscriptExpression::DataMunger::NoSampleConfigurationProfiles);

sub getProtocolName {
  return "rtpcr";
}

1;
