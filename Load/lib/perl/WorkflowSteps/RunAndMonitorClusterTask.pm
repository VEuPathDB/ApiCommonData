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

  my $userName = $ENV{USER};  # perl trick to get user name

  my $propFile = "$clusterDataDir/$taskInputDir/controller.prop";
  my $processIdFile = "$clusterDataDir/$taskInputDir/task.id";
  my $logFile = "$clusterTaskLogsDir/" . $self->getName() . ".log";

  my $success=$self->runAndMonitorClusterTask($test, $userName, $clusterServer, $processIdFile, $logFile, $propFile, $numNodes, 15000, $clusterQueue, $processorsPerNode);
  if (!$success){
      $self->error ("Task did not successfully run. Check log file: $logFile\n");
  }
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
