package ApiCommonData::Load::HaplotypeResults;
use base qw(CBIL::TranscriptExpression::DataMunger::NoSampleConfigurationProfiles);

sub getProtocolName {
  return "haplotype";
}

1;

