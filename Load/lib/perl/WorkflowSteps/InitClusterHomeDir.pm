package ApiCommonData::Load::WorkflowSteps::InitClusterHomeDir;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);
use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test) = @_;

  my $clusterDataDir = $self->getComputeClusterDataDir();
  my $clusterTaskLogsDir = $self->getComputeClusterTaskLogsDir();

  $self->runCmdOnCluster(0, "mkdir -p $clusterDataDir");
  $self->runCmdOnCluster(0, "mkdir -p $clusterTaskLogsDir");
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
