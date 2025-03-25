package ApiCommonData::Load::RNASeqProfileFromSeparateFiles;
use base qw(CBIL::StudyAssayResults::DataMunger::ProfileFromSeparateFiles);

sub getProtocolName {
  return "RNASeq";
}

1;
