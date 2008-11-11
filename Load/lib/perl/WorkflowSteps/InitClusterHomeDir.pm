package GUS::ApiCommonData::Load::WorkflowSteps::InitClusterHomeDir;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);
use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test) = @_;

  # get global properties
  my $projectName = $self->getGlobalConfig('projectName');
  my $projectVersion = $self->getGlobalConfig('projectVersion');
  my $clusterDir = $self->getGlobalConfig('clusterDir');

  $self->runCmdOnCluster(0, "mkdir -p $clusterDir/$projectName/$projectVersion/data");
  $self->runCmdOnCluster(0, "mkdir -p $clusterDir/$projectName/$projectVersion/clusterTaskLogs");

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
