package ApiCommonData::Load::WorkflowSteps::SplitCluster;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test) = @_;

  my $inputFile = $self->getParamValue('inputFile');
  my $smallClustersOutputFile = $self->getParamValue('smallClustersOutputFile');  my $bigClustersOutputFile = $self->getParamValue('bigClustersOutputFile');

  my $localDataDir = $self->getLocalDataDir();

  my $cmd = "splitClusterFile $localDataDir/$inputFile $localDataDir/$smallClustersOutputFile $localDataDir/$bigClustersOutputFile";

  if ($test){
      self->runCmd(0, "echo test > $localDataDir/$smallClustersOutputFile");
      self->runCmd(0, "echo test > $localDataDir/$bigClustersOutputFile");
  }
  self->runCmd($test, $cmd);
}


sub getParamDeclaration {
  return (
     'inputFile',
     'smallClustersOutputFile',
     'bigClustersOutputFile',
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
