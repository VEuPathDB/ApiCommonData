package ApiCommonData::Load::WorkflowSteps::ShortenDefline;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);
use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test) = @_;

  # get parameters
  my $inputFile = $self->getParamValue('inputFile');
  my $outputFile = $self->getParamValue('outputFile');

  my $localDataDir = $self->getLocalDataDir();

  if ($test) {
      $self->runCmd($test, "echo test > $localDataDir/$outputFile");
  }
  $self->runCmd($test, "shortenDefLine --inputFile $localDataDir/$inputFile --outputFile $localDataDir/$outputFile");
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
