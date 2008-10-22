package GUS::ApiCommonData::Load::WorkflowSteps::InitClusterHomeDir;

@ISA = (GUS::Workflow::WorkflowStepInvoker);
use strict;
use GUS::Workflow::WorkflowStepInvoker;

sub run {
  my ($self, $test) = @_;

  # get global properties
  my $projectName = $self->getGlobalConfig('projectName');
  my $projectVersion = $self->getGlobalConfig('projectVersion');
  my $clusterDir = $self->getGlobalConfig('clusterDir');

  $self->runCmdOnCluster(0, "mkdir -p $clusterDir$projectName/$projectVersion/data");
  $self->runCmdOnCluster(0, "mkdir -p $clusterDir$projectName/$projectVersion/logs");

}

sub getConfigDeclaration {
  my $properties =
    [
    ];
  return $properties;
}

sub getParamDeclaration {
  my $properties =
    [];
  return $properties;
}

sub restart {
}

sub undo {

}

sub getDocumentation {
}
