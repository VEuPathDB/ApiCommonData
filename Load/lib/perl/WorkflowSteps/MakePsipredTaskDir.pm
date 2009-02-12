package ApiCommonData::Load::WorkflowSteps::MakePsipredTaskDir;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);
use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test, $undo) = @_;

  # get parameters
  my $taskInputDir = $self->getParamValue('taskInputDir');
  my $proteinsFile = $self->getParamValue('proteinsFile');
  my $nrdbFile = $self->getParamValue('nrdbFile');

  # get step properties
  my $taskSize = $self->getConfig('taskSize');
  my $psipredPath = $self->getConfig('clusterpath');
  my $ncbiBinPath = $self->getConfig('ncbiBinPath');

  my $computeClusterDataDir = $self->getComputeClusterDataDir();
  my $localDataDir = $self->getLocalDataDir();


  if ($test) {
    $self->testInputFile('proteinsFile', "$localDataDir/$proteinsFile");
    $self->testInputFile('nrdbFile', "$localDataDir/$nrdbFile");
  }

  if ($undo) {
    $self->runCmd(0,"rm -rf $localDataDir/$taskInputDir");
  }else {
    $self->runCmd(0,"mkdir -p $localDataDir/$taskInputDir");

    # make controller.prop file
    $self->makeClusterControllerPropFile($taskInputDir, 2, $taskSize,
				       "DJob::DistribJobTasks::PsipredTask");

    # make task.prop file
    my $taskPropFile = "$localDataDir/$taskInputDir/task.prop";
    open(F, ">$taskPropFile") || die "Can't open task prop file '$taskPropFile' for writing";

    print F
"psipredDir=$psipredPath
dbFilePath=$computeClusterDataDir/$nrdbFile
inputFilePath=$computeClusterDataDir/$proteinsFile
ncbiBinDir=$ncbiBinPath
";
    close(F);
  }
}

sub getParamsDeclaration {
  return (
          'taskInputDir',
          'proteinsFile',
          'nrdbFile',
         );
}

sub getConfigDeclaration {
  return (
         # [name, default, description]
           ['ncbiBinPath', '', ''],
           ['psipredPath', '', ''],
           ['taskSize', '', ''],
         );
}

