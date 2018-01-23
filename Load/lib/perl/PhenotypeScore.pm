package ApiCommonData::Load::PhenotypeScore;
use base qw(ApiCommonData::Load::GenericStudyResult);

sub new {
  my ($class, $args) = @_;

  my $self = $class->SUPER::new($args);

  $self->setSourceIdType("gene");
  $self->setProtocolName("phenotype_score");

  return $self;
}

1;
