package ApiCommonData::Load::GenericProfiles;
use base qw(CBIL::StudyAssayResults::DataMunger::NoSampleConfigurationProfiles);

sub getProtocolName {
  my ($self) = @_;

  my $technologyType = $self->getTechnologyType();

  return $technologyType;
}

1;
