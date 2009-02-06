package ApiCommonData::Load::WorkflowSteps::GrepMercatorGff;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);
use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
  my ($self, $test, $undo) = @_;

  # get parameters
  my $inputFile = $self->getParamValue('inputFile');
  my $outputFile = $self->getParamValue('outputFile');

  my $localDataDir = $self->getLocalDataDir();

  my $cmd = "grep -P '\texon\t' ${localDataDir}/$inputFile |sed 's/apidb|//'  > ${localDataDir}/$outputFile; grep -P '\tCDS\t' ${localDataDir}/$inputFile |sed 's/apidb|//'  > ${localDataDir}/$outputFile";

  if ($test) {
    $self->runCmd(0, "echo test > ${localDataDir}/$outputFile");
  }elsif ($undo) {
    $self->runCmd(0, "rm -f $localDataDir/$outputFile");
  }else {
    $self->runCmd($test, $cmd);
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

