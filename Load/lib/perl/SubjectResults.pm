package ApiCommonData::Load::SubjectResults;
use base qw(CBIL::StudyAssayResults::DataMunger::NoSampleConfigurationProfiles);

sub getProtocolName {
  return "subject_result";
}

sub getSourceIdType {
  return "subject"
}

1;

