package ApiCommonData::Load::GenericStudyResult;
use base qw(CBIL::StudyAssayResults::DataMunger::Loadable);


sub new {
  my ($class, $args) = @_;

  my $requiredParams = [ 'outputFile',
                         'profileSetName',
                         'sampleName',
                       ];

  my $self = $class->SUPER::new($args, $requiredParams);

  $self->setNames([$args->{sampleName}]);
  $self->setFileNames([$args->{outputFile}]);

  return $self;
}


sub munge {
  my $self = shift;

  $self->createConfigFile();

}


1;
