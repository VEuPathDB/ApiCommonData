package ApiCommonData::Load::RNASeqProfileFromSeparateFiles;
use base qw(CBIL::TranscriptExpression::DataMunger::ProfileFromSeparateFiles);

sub getProtocolName {
  return "RNASeq";
}

1;
