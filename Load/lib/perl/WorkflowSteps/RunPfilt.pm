package ApiCommonData::Load::WorkflowSteps::RunPfilt;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);
use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
  my ($self, $test, $undo) = @_;

  # get parameters
  my $inputFile = $self->getParamValue('inputFile');
  my $outputFile = $self->getParamValue('outputFile');

  # get step properties
  my $psipredPath = $self->getConfig('psipredPath');

  my $localDataDir = $self->getLocalDataDir();

  if ($test) {
    $self->testInputFile('inputFile', "$localDataDir/$inputFile");
    $self->runCmd(0, "echo test > $localDataDir/$outputFile");
  }

  if ($undo) {
    $self->runCmd(0, "rm -f $localDataDir/$outputFile");
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
          ['psipredPath', '', ''],
         );
}

