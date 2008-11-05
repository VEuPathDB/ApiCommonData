package ApiCommonData::Load::WorkflowSteps::RunTmhmm;

@ISA = (GUS::Workflow::WorkflowStepInvoker);

use strict;
use GUS::Workflow::WorkflowStepInvoker;


sub run {
  my ($self, $test) = @_;

  my $outputFile = $self->getParamValue('outputFile');

  my $proteinsFile = $self->getParamValue('proteinsFile');

  my $binPath = $self->getConfig('path');

  my $cmd = "runTMHMM -binPath $binPath -short -seqFile $proteinsFile -outFile $outputFile";

  if ($test) {

      $self->runCmd(0,"test > $outputFile");

  } else {

      $self->runCmd($test,$cmd);

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
     ['proteinsFile', "", ""],
     ['outputFile', "", ""],
    );
  return @properties;
}

sub getDocumentation {
}
