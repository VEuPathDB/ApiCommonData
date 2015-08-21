package ApiCommonData::Load::RtPCRAnalysis;
use base qw(CBIL::TranscriptExpression::DataMunger::Standardization);

sub getProtocol {
  return "rtpcr";
}

1;
