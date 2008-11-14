package ApiCommonData::Load::WorkflowSteps::RunPfilt;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);
use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

TEMPLATE
sub run {
  my ($self, $test) = @_;

  # get parameters
  my $inputFile = $self->getParamValue('inputFile');
  my $outputFile = $self->getParamValue('outputFile');

  # get step properties
  my $psipredPath = $self->getConfig('psipredPath');

  my $localDataDir = $self->getLocalDataDir();

  if ($test) {
    $self->runCmd(0, "echo test > $localDataDir/$outputFile");
  } else {
    $self->runCmd($test, "$psipredPath/pfilt $localDataDir/$inputFile > $localDataDir/$outputFile");
  }
}

sub getParamsDeclaration {
  return (
          'inputFile',
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
