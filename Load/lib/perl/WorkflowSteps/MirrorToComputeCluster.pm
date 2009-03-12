package ApiCommonData::Load::WorkflowSteps::MirrorToComputeCluster;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;
use File::Basename;

sub run {
  my ($self, $test, $undo) = @_;

  # get param values
  my $fileOrDirToMirror = $self->getParamValue('fileOrDirToMirror');

  my $localDataDir = $self->getLocalDataDir();
  my $computeClusterDataDir = $self->getComputeClusterDataDir();

  my ($filename, $relativeDir) = fileparse($fileOrDirToMirror);

  if($undo){
      $self->runCmdOnCluster(0, "rm -fr $computeClusterDataDir/$fileOrDirToMirror");
  }else{

      $self->copyToCluster("$localDataDir/$relativeDir",
			   $filename,
			   "$computeClusterDataDir/$relativeDir");
  }
}

sub getParamDeclaration {
  return (
	  'fileOrDirToMirror',
	 );
}

sub getConfigDeclaration {
  return (
	  # [name, default, description]
	 );
}

