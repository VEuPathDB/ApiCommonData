package ApiCommonData::Load::SubjectResults;
use base qw(CBIL::TranscriptExpression::DataMunger::NoSampleConfigurationProfiles);

sub getProtocolName {
  return "subject_result";
}

sub getSourceIdType {
  return "subject"
}

1;

