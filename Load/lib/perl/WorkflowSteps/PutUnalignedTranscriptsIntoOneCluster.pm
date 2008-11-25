package ApiCommonData::Load::WorkflowSteps::PutUnalignedTranscriptsIntoOneCluster;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test) = @_;

  my $allClustersOutputFile = $self->getParamValue('allClustersOutputFile');
  my $alignedClustersFile = $self->getParamValue('alignedClustersFile');
  my $repeatMaskErrFile = $self->getParamValue('repeatMaskErrFile');

  my $localDataDir = $self->getLocalDataDir();

  my $cmd = "getUnalignedAssemSeqIds --alignedClustersFile $localDataDir/$alignedClustersFile --outputFile $localDataDir/$allClustersOutputFile --repeatMaskErrFile $localDataDir/$repeatMaskErrFile";

  if ($test) {
      $self->runCmd(0, "echo test > $localDataDir/$allClustersOutputFile");
  }
  $self->runCmd($test, $cmd);
}


sub getParamsDeclaration {
  return (
     'alignedClustersFile',
     'allClustersOutputFile',
     'repeatMaskErrFile',
    );
}

sub getConfigDeclaration {
  return (
	  # [name, default, description]
	 );
}

sub restart {
}

sub undo {

}

sub getDocumentation {
}
