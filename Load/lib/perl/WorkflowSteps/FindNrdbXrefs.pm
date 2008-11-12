package GUS::ApiCommonData::Load::WorkflowSteps::FindNrdbXrefs;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);
use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

TEMPLATE
sub run {
  my ($self, $test) = @_;

  # get parameters
  my $proteinsFile = $self->getParamValue('proteinsFile');
  my $nrdbFile = $self->getParamValue('nrdbFile');
  my $proteinsFileRegex = $self->getParamValue('proteinsFileRegex');
  my $nrdbFileRegex = $self->getParamValue('nrdbFileRegex');
  my $outputFile = $self->getParamValue('outputFile');

  # get global properties
  my $ = $self->getGlobalConfig('');

  # get step properties
  my $ = $self->getConfig('');

  if ($test) {
  } else {
  }

  $self->runPlugin($test, '', $args);

}

sub getParamsDeclaration {
  return (
          'proteinsFile',
          'nrdbFile',
          'proteinsFileRegex',
          'nrdbFileRegex',
          'outputFile',
         );
}

sub getConfigDeclaration {
  return (
         # [name, default, description]
         # ['', '', ''],
         );
}

sub restart {
}

sub undo {

}

sub getDocumentation {
}
