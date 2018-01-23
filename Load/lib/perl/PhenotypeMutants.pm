package ApiCommonData::Load::PhenotypeMutants;
use base qw(ApiCommonData::Load::GenericStudyResult);


sub new {
  my ($class, $args) = @_;

  my $self = $class->SUPER::new($args);

  $self->setSourceIdType("gene");
  $self->setProtocolName("phenotype_knockout_mutants");

  return $self;
}


1;
