package ApiCommonData::Load::PhenotypeGrowthRate;
use base qw(ApiCommonData::Load::GenericStudyResult);

sub new {
  my ($class, $args) = @_;

  my $self = $class->SUPER::new($args);

  $self->setSourceIdType("gene");
  $self->setProtocolName("phenotype_growth_rate");

  return $self;
}

1;
