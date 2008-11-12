package ApiCommonData::Load::WorkflowSteps::PutUnalignedTranscriptsIntoOneCluster;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test) = @_;

  my $allClustersOutputFile = $self->getParamValue('allClustersOutputFile');
  my $alignedClustersFile = $self->getParamValue('alignedClustersFile');
  my $repeatMaskErrFile = $self->getParamValue('repeatMaskErrFile');

  my $cmd = "getUnalignedAssemSeqIds --alignedClustersFile $alignedClustersFile --outputFile $allClustersOutputFile --repeatMaskErrFile $repeatMaskErrFile";

  if ($test) {
      self->runCmd(0, "echo test > $allClustersOutputFile");
  } else {
      self->runCmd($test, $cmd);
  }
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
