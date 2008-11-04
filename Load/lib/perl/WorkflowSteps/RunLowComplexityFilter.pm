package ApiCommonData::Load::WorkflowSteps::RunLowComplexityFilter;

@ISA = (GUS::Workflow::WorkflowStepInvoker);

use strict;
use GUS::Workflow::WorkflowStepInvoker;


sub run {
  my ($self, $test) = @_;

  my $seqFile = $self->getParamValue('seqFile');

  my $outputFile = $self->getParamValue('outputFile');
  
  my $filterType = $self->getParamValue('filterType'); 

  my $options = $self->getParamValue('options');

  my $blastDir = $self->getConfig('wuBlastPath');

  my $filter = "$blastDir/filter/$filterType";

  if ($test) {
      $self->runCmd(0,"test > $outputFile");
  } else {
      self->runCmd($test,"$filter $seqFile $options > $outputFile"); 
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
     ['seqFile', "", ""],
     ['outputFile', "", ""],
     ['filterType', "", ""],
     ['options',"",""],
    );
  return @properties;
}

sub getDocumentation {
}
1
