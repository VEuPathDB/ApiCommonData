package ApiCommonData::Load::WorkflowSteps::MirrorFromComputeCluster;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;
use File::Basename;

sub run {
  my ($self, $test) = @_;

  # get param values
  my $fileOrDirToMirror = $self->getParamValue('fileOrDirToMirror');
  my $outputDir = $self->getParamValue('outputDir');
  my $outputFile = $self->getParamValue('outputFile');

  my $localDataDir = $self->getLocalDataDir();
  my $computeClusterDataDir = $self->getComputeClusterDataDir();

  my ($filename, $relativeDir) = fileparse($fileOrDirToMirror);

  $self->copyFromCluster($test, "$computeClusterDataDir/$relativeDir",
			 $filename,
			 "$localDataDir/$relativeDir");

  if ($test) {
    $self->runCmd(0, "mkdir -p $localDataDir/$outputDir");
    if ($outputFile) {
      $self->runCmd(0, "echo test > $localDataDir/$outputDir/$outputFile")
    };
  }
}

sub getParamDeclaration {
  return (
	  'fileOrDirToMirror',
	  'outputDir',
	  'outputFile',
	 );
}

sub getConfigDeclaration {
  return (
	  # [name, default, description]
	 );
}

sub restart {
}

sub undo {

}

sub getDocumentation {
}
