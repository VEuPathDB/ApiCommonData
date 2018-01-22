package ApiCommonData::Load::PhenotypeMutants;
use base qw(CBIL::TranscriptExpression::DataMunger::Loadable);


sub new {
  my ($class, $args) = @_;

  my $requiredParams = [ 'outputFile',
                         'profileSetName',
                       ];

  my $self = $class->SUPER::new($args, $requiredParams);

  $self->setSourceIdType("gene");
  $self->setNames([$args->{profileSetName}]);
  $self->setFileNames([$args->{outputFile}]);
  $self->setProtocolName("phenotype_knockout_mutants");

  return $self;
}


sub munge {
  my $self = shift;

  $self->createConfigFile();

}


1;
