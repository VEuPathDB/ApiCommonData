package ApiCommonData::Load::WorkflowSteps::InitClusterHomeDir;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);
use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test) = @_;

  my $clusterHomeDir = $self->getComputeClusterHomeDir();

  $self->runCmdOnCluster(0, "mkdir -p $clusterHomeDir/data");
  $self->runCmdOnCluster(0, "mkdir -p $clusterHomeDir/clusterTaskLogs");
}

sub getParamsDeclaration {
  return (
	 );
}

sub getConfigDeclaration {
  return (
	 );
}

sub restart {
}

sub undo {

}

sub getDocumentation {
}
