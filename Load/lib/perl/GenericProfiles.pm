package ApiCommonData::Load::GenericProfiles;
use base qw(CBIL::TranscriptExpression::DataMunger::NoSampleConfigurationProfiles);

sub getProtocolName {
  my $technologyType = $self->getTechnologyType();

  return $technologyType;
}

1;
