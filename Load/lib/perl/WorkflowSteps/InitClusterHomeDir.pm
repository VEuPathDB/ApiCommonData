package ApiCommonData::Load::WorkflowSteps::InitClusterHomeDir;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);
use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test, $undo) = @_;

  my $clusterDataDir = $self->getComputeClusterDataDir();
  my $clusterTaskLogsDir = $self->getComputeClusterTaskLogsDir();



   if ($undo) {
      $self->runCmdOnCluster(0, "rm -fr $clusterDataDir");
      $self->runCmdOnCluster(0, "rm -fr $clusterTaskLogsDir");
   } else { 
       
      $self->runCmdOnCluster(0, "mkdir -p $clusterDataDir");
      $self->runCmdOnCluster(0, "mkdir -p $clusterTaskLogsDir");
   }

}

sub getParamsDeclaration {
  return (
	 );
}

sub getConfigDeclaration {
  return (
	 );
}


