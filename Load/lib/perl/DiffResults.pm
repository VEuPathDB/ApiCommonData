package ApiCommonData::Load::DiffResults;
use base qw(CBIL::TranscriptExpression::DataMunger::NoSampleConfigurationProfiles);

sub getProtocolName {
  return "differential expression analysis data transformation";
}

1;
