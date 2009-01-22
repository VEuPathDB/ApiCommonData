package ApiCommonData::Load::WorkflowSteps::MakeRepeatMaskTaskInputDir;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);
use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test) = @_;

  # get parameters
  my $taskInputDir = $self->getParamValue('taskInputDir');
  my $seqsFile = $self->getParamValue('seqsFile');
  my $options = $self->getParamValue('options');
  my $dangleMax = $self->getParamValue('dangleMax');

  # get step properties
  my $taskSize = $self->getConfig('taskSize');
  my $rmPath = $self->getConfig('rmPath');

  my $computeClusterDataDir = $self->getComputeClusterDataDir();
  my $localDataDir = $self->getLocalDataDir();

  $self->runCmd(0,"mkdir -p $localDataDir/$taskInputDir");

  # make controller.prop file
  $self->makeClusterControllerPropFile($taskInputDir, 2, $taskSize,
				       "DJob::DistribJobTasks::RepeatMaskerTask");

  if ($test) {
    $self->testInputFile('seqsFile', "$localDataDir/$seqsFile");
  }

  # make task.prop file
  my $taskPropFile = "$localDataDir/$taskInputDir/task.prop";
  open(F, ">$taskPropFile") || die "Can't open task prop file '$taskPropFile' for writing";

    print F 
"rmPath=$rmPath
inputFilePath=$computeClusterDataDir/$seqsFile
trimDangling=y
rmOptions=$options
dangleMax=$dangleMax
";
    close(F);

}

sub getParamsDeclaration {
  return (
          'taskInputDir',
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
