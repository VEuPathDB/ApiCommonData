package ApiCommonData::Load::QuantitativeProteomicsSeparateFilesAnalysis;
use base qw(CBIL::StudyAssayResults::DataMunger::Loadable);

use strict;

sub getSample { $_[0]->{sample}}
sub setSample { $_[0]->{sample} = $_ }

sub new {
  my ($class, $args) = @_;

  my $requiredParams = [ 'outputFile',
                         'sample',
                         'profileSetName',
                       ];

  my $self = $class->SUPER::new($args, $requiredParams);

  $self->setSourceIdType("gene");
  $self->setNames([$args->{sample}]);
  $self->setFileNames([$args->{outputFile}]);

  return $self;
}


sub munge {
  my $self = shift;

  $self->createConfigFile();

}

sub getProtocolName {
  return "Quantitative Proteomics";
}

1;

