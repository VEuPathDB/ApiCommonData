package ApiCommonData::Load::WorkflowSteps::RunAndMonitorClusterTask;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);
use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test) = @_;

  # get parameters
  my $taskInputDir = $self->getParamValue('taskInputDir');
  my $numNodes = $self->getParamValue('numNodes');
  my $processorsPerNode = $self->getParamValue('processorsPerNode');

  # get global properties
  my $clusterServer = $self->getWorkflowConfig('clusterServer');
  my $clusterQueue = $self->getGlobalConfig('clusterQueue');

  my $clusterTaskLogsDir = $self->getComputeClusterTaskLogsDir();
  my $clusterDataDir = $self->getComputeClusterDataDir();

  my $userName = (caller(0))[3];  # perl trick to get user name

  my $propFile = "$clusterDataDir/$taskInputDir/task.prop";
  my $logFile = "$clusterTaskLogsDir/" . $self->getName() . ".log";

  $self->runAndMonitorClusterTask($test, $userName, $clusterServer, $logFile, $propFile, $numNodes, 15000, $clusterQueue, $processorsPerNode);
}

sub getParamsDeclaration {
  return (
          'taskInputDir',
          'numNodes',
         );
}

sub getConfigDeclaration {
  return (
         # [name, default, description]
         # ['', '', ''],
         );
}

sub restart {
}

sub undo {

}

sub getDocumentation {
}
