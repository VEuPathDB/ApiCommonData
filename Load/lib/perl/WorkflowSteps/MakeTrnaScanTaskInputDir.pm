package ApiCommonData::Load::WorkflowSteps::MakeTrnaScanTaskInputDir;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test, $undo) = @_;

  # get parameter values
  my $taskInputDir = $self->getParamValue("taskInputDir");
  my $genomicSeqsFile = $self->getParamValue("genomicSeqsFile");

  my $taskSize = $self->getConfig('taskSize');
  my $tRNAscanDir = $self->getConfig('tRNAscanDir');


  my $computeClusterDataDir = $self->getComputeClusterDataDir();
  my $localDataDir = $self->getLocalDataDir();

  if ($test) {
    $self->testInputFile('genomicSeqsFile', "$localDataDir/$genomicSeqsFile");
  }

  if ($undo) {
    $self->runCmd(0, "rm -rf $localDataDir/$taskInputDir/");
  }else {
    $self->runCmd(0,"mkdir -p $localDataDir/$taskInputDir");

    # make controller.prop file
    $self->makeClusterControllerPropFile($taskInputDir, 2, $taskSize,
				       "DJob::DistribJobTasks::tRNAscanTask"); 

    # make task.prop file
    my $taskPropFile = "$localDataDir/$taskInputDir/task.prop";
    open(F, ">$taskPropFile") || die "Can't open task prop file '$taskPropFile' for writing";

    print F
"tRNAscanDir=$tRNAscanDir
inputFilePath=$computeClusterDataDir/$genomicSeqsFile
trainingOption=C
";
    close(F);

  }
}

sub getParamsDeclaration {
  return ('taskInputDir',
	  'genomicSeqsFile',
	 );
}

sub getConfigDeclaration {
  return (
	  # [name, default, description]
	  ['taskSize', "", ""],
	  ['tRNAscanDir', "", ""],
	 );
}

