package ApiCommonData::Load::WorkflowSteps::ExtractIdsFromBlastResult;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
  my ($self, $test, $undo) = @_;

  my $inputFile = $self->getParamValue('inputFile');
  my $idType = $self->getParamValue('idType');
  my $outputFile = $self->getParamValue('outputFile');

  my $localDataDir = $self->getLocalDataDir();
  my $cmd = "makeIdFileFromBlastSimOutput --$idType --subject --blastSimFile $localDataDir/$inputFile --outFile $localDataDir/$outputFile";

  if ($undo) {
    $self->runCmd(0, "rm -f $localDataDir/$outputFile");
  } else {
      if ($test) {
	  $self->testInputFile('inputFile', "$localDataDir/$inputFile");
	  $self->runCmd(0,"echo test > $localDataDir/$outputFile");
      }else{
	  $self->runCmd($test,$cmd);
      }
  }

}

sub getParamsDeclaration {
  return (
	  'idType',
	  'outputFile',
	  'inputFile',
	 );
}

sub getConfigDeclaration {
  return
    (
    );
}

