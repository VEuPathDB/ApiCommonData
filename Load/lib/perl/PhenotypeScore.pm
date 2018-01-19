package ApiCommonData::Load::PhenotypeScore;
use base qw(CBIL::TranscriptExpression::DataMunger::NoSampleConfigurationProfiles);

sub getProtocolName {
  my $technologyType = $self->getTechnologyType();

  die unless($technologyType eq 'phenotype_score');

  return $technologyType;
}

1;
