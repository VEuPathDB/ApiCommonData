package ApiCommonData::Load::WorkflowSteps::SplitCluster;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test) = @_;

  my $clusterFile = $self->getParamValue('inputFile');

  my $cmd = "splitClusterFile $clusterFile";

  if ($test){
      self->runCmd(0,'echo hello > $clusterFile.small');
      self->runCmd(0,'echo hello > $clusterFile.big');
  }else{
      self->runCmd($test,$cmd);      
  }

}


sub restart {
}

sub undo {

}

sub getConfigDeclaration {
  my @properties = 
    (
     # [name, default, description]
    );
  return @properties;
}

sub getParamDeclaration {
  my @properties = 
    (
     # [name, default, description]
     ['inputFile'],
    );
  return @properties;
}

sub getDocumentation {
}
