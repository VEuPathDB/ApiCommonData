package ApiCommonData::Load::WorkflowSteps::formatDownloadFile;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);
use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

TEMPLATE
sub run {
  my ($self, $test) = @_;

  # get parameters
  my $inputFile = $self->getParamValue('inputFile');
  my $outputDir = $self->getParamValue('outputDir');
  my $args = $self->getParamValue('args');

  # get global properties
  my $ = $self->getGlobalConfig('');

  # get step properties
  my $ = $self->getConfig('');

  my $localDataDir = $self->getLocalDataDir();

  if ($test) {
  } else {
  }

  $self->runPlugin($test, '', $args);

}

sub getParamsDeclaration {
  return (
          'inputFile',
          'outputDir',
          'args',
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
