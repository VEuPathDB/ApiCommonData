package ApiCommonData::Load::WorkflowSteps::RunExportPred;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
  my ($self, $test, $undo) = @_;

  my $proteinsFile = $self->getParamValue('proteinsFile');
  my $outputFile = $self->getParamValue('outputFile');

  my $binPath = $self->getConfig('binPath');

  my $localDataDir = $self->getLocalDataDir();

  my $cmd = "${binPath}/exportpred --input=$localDataDir/$proteinsFile --output=$localDataDir/$outputFile";

  if ($test) {
      $self->testInputFile('proteinsFile', "$localDataDir/$proteinsFile");
      $self->runCmd(0,"echo test > $localDataDir/$outputFile");
  }

  if ($undo) {
    $self->runCmd(0, "rm -f $localDataDir/$outputFile");
  } else {
    $self->runCmd($test,$cmd);
  }
}

sub getParamDeclaration {
  return (
     'proteinsFile',
     'outputFile',
    );
}

sub getConfigDeclaration {
  return (
	  # [name, default, description]
	  ['binPath', "", ""],
	 );
}

