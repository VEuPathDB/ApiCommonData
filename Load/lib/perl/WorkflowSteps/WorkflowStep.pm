package ApiCommonData::Load::WorkflowSteps::WorkflowStep;

########################################
## Super class for ApiDB workflow steps
########################################

@ISA = (GUS::Workflow::WorkflowStepInvoker);

use strict;

use GUS::Workflow::WorkflowStepInvoker;

sub getLocalDataDir {
    my ($self) = @_;
    my $workflowHome = $self->getWorkflowHomeDir();
    return "$workflowHome/data";
}

sub getComputeClusterHomeDir {
    my ($self) = @_;
    my $clusterBase = $self->getGlobalConfig('clusterBaseDir');
    my $workflowName = $self->getWorkflowName();
    my $workflowVersion = $self->getWorkflowVersion();
    return "$clusterBase/$workflowName/$workflowVersion";
}

sub getComputeClusterDataDir {
    my ($self) = @_;
    my $home = $self->getComputeClusterHomeDir();
    return "$home/data";
}

sub makeControllerPropFile {
  my ($self, $taskInputDir, $slotsPerNode, $taskSize, $nodePath, $taskClass, $nodeClass) = @_;

  # tweak inputs
  my $masterDir = $taskInputDir;
  $masterDir =~ s/master/input/;
  $nodeClass = 'DJob::DistribJob::BprocNode' unless $nodeClass;
  
  # get configuration values
  my $nodePath = $self->getConfig('nodePath');
  my $nodeClass = $self->getConfig('nodeClass');

  # construct dir paths
  my $localDataDir = $self->getLocalDataDir();
  my $computeClusterDataDir = $self->getComputeClusterDataDir();

  # print out the file
  my $controllerPropFile = "$localDataDir/$taskInputDir/controller.prop";
  open(F, $controllerPropFile) 
      || die "Can't open controller prop file '$controllerPropFile' for writing";
  print F 
"masterdir=$computeClusterDataDir/$masterDir
inputdir=$computeClusterDataDir/$taskInputDir
nodedir=$nodePath
slotspernode=$slotsPerNode
subtasksize=$taskSize
taskclass=$taskClass
nodeclass=$nodeClass
restart=no
";
    close(F);
}
