package ApiCommonData::Load::WorkflowSteps::MakePsipredTaskDir;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);
use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test) = @_;

  # get parameters
  my $taskInputDir = $self->getParamValue('taskInputDir');
  my $proteinsFile = $self->getParamValue('proteinsFile');
  my $nrdbFile = $self->getParamValue('nrdbFile');

  # get step properties
  my $taskSize = $self->getConfig('taskSize');
  my $psipredPath = $self->getConfig('psipredPath');
  my $ncbiBinPath = $self->getConfig('ncbiBinPath');

  # make controller.prop file
  $self->makeControllerPropFile($taskInputDir, 2, $taskSize,
				       "DJob::DistribJobTasks::PsipredTask");

  # make task.prop file
  my $computeClusterDataDir = $self->getComputeClusterDataDir();
  my $localDataDir = $self->getLocalDataDir();

  my $taskPropFile = "$localDataDir/$taskInputDir/task.prop";
  open(F, $taskPropFile) || die "Can't open task prop file '$taskPropFile' for writing";

  print F
"psipredDir=$psipredPath
dbFilePath=$computeClusterDataDir/$nrdbFile
inputFilePath=$computeClusterDataDir/$proteinsFile
ncbiBinDir=$ncbiBinPath
";
    close(F);
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
         # ['', '', ''],
         );
}

sub restart {
}

sub undo {

}

sub getDocumentation {
}
