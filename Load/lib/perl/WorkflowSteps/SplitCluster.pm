package ApiCommonData::Load::WorkflowSteps::SplitCluster;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test) = @_;

  my $clusterFile = $self->getParamValue('inputFile');
  my $smallClustersOutputFile = $self->getParamValue('smallClustersOutputFile');
  my $bigClustersOutputFile = $self->getParamValue('bigClustersOutputFile');
  my $cmd = "splitClusterFile $clusterFile $smallClustersOutputFile $bigClustersOutputFile";

  if ($test){
      self->runCmd(0, "echo test > $smallClustersOutputFile");
      self->runCmd(0, "echo test > $bigClustersOutputFile");
  } else {
      self->runCmd($test, $cmd);
  }
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
