package ApiCommonData::Load::RtPCRAnalysis;
use base qw(CBIL::TranscriptExpression::DataMunger::Standardization);

sub getProtocolName {
  return "rtpcr";
}

1;
