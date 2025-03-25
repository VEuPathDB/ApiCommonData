package ApiCommonData::Load::RNASeqProfiles;
use base qw(CBIL::StudyAssayResults::DataMunger::NoSampleConfigurationProfiles);

sub getProtocolName {
  return "RNASeq";
}

1;
