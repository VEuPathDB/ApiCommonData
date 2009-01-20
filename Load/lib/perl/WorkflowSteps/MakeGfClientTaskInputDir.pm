package ApiCommonData::Load::WorkflowSteps::MakeGfClientTaskInputDir;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test) = @_;

  # get parameter values
  my $taskInputDir = $self->getParamValue("taskInputDir");
  my $maxIntronSize = $self->getParamValue("maxIntronSize");
  my $queryFile = $self->getParamValue("queryFile");
  my $targetDir = $self->getParamValue("targetDir");

  my $taskSize = $self->getConfig('taskSize');
  my $gaBinPath = $self->getConfig('gaBinPath');

  my $computeClusterDataDir = $self->getComputeClusterDataDir();
  my $localDataDir = $self->getLocalDataDir();

  $self->runCmd(0,"mkdir $localDataDir/$taskInputDir");

  # make controller.prop file
  $self->makeClusterControllerPropFile($taskInputDir, 2, $taskSize,
				       "DJob::DistribJobTasks::GenomeAlignWithGfClientTask");

  if ($test) {
    $self->testInputFile('queryFile', "$localDataDir/$queryFile");
    $self->testInputFile('targetDir', "$localDataDir/$targetDir");
  }

  # make task.prop file
  my $taskPropFile = "$localDataDir/$taskInputDir/task.prop";
  open(F, ">$taskPropFile") || die "Can't open task prop file '$taskPropFile' for writing";

  print F
"gaBinPath=$gaBinPath
targetDirPath=$computeClusterDataDir/$targetDir/nib
queryPath=$computeClusterDataDir/$queryFile
nodePort=5550
maxIntron=$maxIntronSize
";
  close(F);

  $self->makeGenomeTargetListFile("$localDataDir/$targetDir",
				  "$localDataDir/$taskInputDir/targetList",
				  "$computeClusterDataDir/$taskInputDir/targetList");

  #&runCmd($test, "chmod -R g+w $localDataDir/similarity/$queryName-$subjectName");
}

sub makeGenomeTargetListFile {
    my ($self, $inputDir, $outputFile, $clusterOutputDir) = @_; 

    open(F, ">$outputFile") || die "Can't open $outputFile for writing";

    opendir(D,$inputDir) || die "Can't open directory, $inputDir";

    while(my $file = readdir(D)) {
      next() if ($file =~ /^\./);
      print F "$clusterOutputDir/$file\n";
    }

    closedir(D);
    close(F);
}


sub getParamsDeclaration {
  return ('taskInputDir',
	  'queryFile',
	  'targetDir',
	  'maxIntronSize',
	 );
}

sub getConfigDeclaration {
  return (
	  # [name, default, description]
	  ['taskSize', "", ""],
	  ['gaBinPath', "", ""],
	 );
}

sub restart {
}

sub undo {

}

sub getDocumentation {
}
