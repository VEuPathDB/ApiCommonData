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
  my $outputFiles = $self->getParamValue('outputFiles');

  my $localDataDir = $self->getLocalDataDir();
  my $computeClusterDataDir = $self->getComputeClusterDataDir();

  my ($filename, $relativeDir) = fileparse($fileOrDirToMirror);

  if ($test) {
    $self->runCmd(0, "mkdir -p $localDataDir/$outputDir");
    if ($outputFiles) {
      my @outputFiles = split(/\,\s*/,$outputFiles);
      foreach my $outputFile (@outputFiles) {
	$self->runCmd(0, "echo test > $localDataDir/$outputDir/$outputFile")
      }
    };
  } else {
    $self->copyFromCluster("$computeClusterDataDir/$relativeDir",
			   $filename,
			   "$localDataDir/$relativeDir");
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
