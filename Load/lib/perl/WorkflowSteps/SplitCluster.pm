package ApiCommonData::Load::WorkflowSteps::SplitCluster;

@ISA = (GUS::Workflow::WorkflowStepInvoker);

use strict;
use GUS::Workflow::WorkflowStepInvoker;

sub run {
  my ($self, $test) = @_;

  my $clusterFile = $self->getParamValue('inputFile');

  my $cmd = "splitClusterFile $clusterFile";

  if ($test){
      self->runCmd(0,'test > $clusterFile.small');
      self->runCmd(0,'test > $clusterFile.big');
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
     ['parentNcbiTaxonId', "", ""],
     ['useTaxonHierarchy', "", ""],
     ['predictedTranscriptsSql', "", ""],
    );
  return @properties;
}

sub getDocumentation {
}
