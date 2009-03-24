package ApiCommonData::Load::WorkflowSteps::RunNibOnCluster;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
  my ($self, $test, $undo) = @_;

  my $inputFile = $self->getParamValue('inputFile');
  my $outputDir = $self->getParamValue('outputDir');

  my $localDataDir = $self->getLocalDataDir();
  my $computeClusterDataDir = $self->getComputeClusterDataDir();

  my $cmd = "runFaToNib --filesFile $computeClusterDataDir/$inputFile";

  if ($undo) {
    $self->runCmdOnCluster(0,"rm -f $computeClusterDataDir/$outputDir/test.nib");
  } else {
      if ($test) {
	  $self->testInputFile('inputFile', "$localDataDir/$inputFile");
	  $self->testInputFile('outputDir', "$localDataDir/$outputDir");
	  $self->runCmdOnCluster(0,"echo test > $computeClusterDataDir/$outputDir/test.nib") unless $undo;
      }else{
	  $self->runCmdOnCluster($test,$cmd);
      }
  }
}

sub getParamDeclaration {
  return (
     'inputFile',
     'outputDir',
    );
}

sub getConfigDeclaration {
  return (
	  # [name, default, description]
	  ['computeClusterDataDir', "", ""],
	 );
}

