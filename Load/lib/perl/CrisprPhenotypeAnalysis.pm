package ApiCommonData::Load::CrisprPhenotypeAnalysis;
use base qw(CBIL::StudyAssayResults::DataMunger::Loadable);

use strict;

sub new {
  my ($class, $args) = @_;

  my $requiredParams = [
                          'profileSetName',
                          'inputFile',
                          'sourceIdType',
                         ];
  my $self = $class->SUPER::new($args, $requiredParams);
  return $self;
}

sub munge {
  my ($self) = @_;

  $self->setProtocolName("crispr_phenotype");

  my $pan = $self->getProfileSetName();
  $self->setNames([$pan]);

  my $inputFile = $self->getInputFile();
  $self->setFileNames([$inputFile]);

  $self->createConfigFile();
}


1;
