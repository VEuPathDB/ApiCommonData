package ApiCommonData::Load::QuantitativeProteomicsAnalysis;
use base qw(CBIL::TranscriptExpression::DataMunger::NoSampleConfigurationProfiles);

sub getProtocol {
  return "Quantitative Proteomics";
}

1;
