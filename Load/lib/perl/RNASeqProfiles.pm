package ApiCommonData::Load::RNASeqProfiles;
use base qw(CBIL::TranscriptExpression::DataMunger::NoSampleConfigurationProfiles);

sub getProtocolName {
  return "RNASeq";
}

1;
