package ApiCommonData::Load::WorkflowSteps::RunTmhmm;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
  my ($self, $test) = @_;

  my $outputFile = $self->getParamValue('outputFile');
  my $proteinsFile = $self->getParamValue('proteinsFile');
  my $binPath = $self->getConfig('path');

  my $cmd = "runTMHMM -binPath $binPath -short -seqFile $proteinsFile -outFile $outputFile";

  if ($test) {
      $self->runCmd(0,"echo test > $outputFile");
  } else {
      $self->runCmd($test,$cmd);
  }

}

sub getParamDeclaration {
  return (
     'proteinsFile',
     'outputFile',
    );
}

sub getConfigDeclaration {
  return (
	  # [name, default, description]
	  ['binPath', "", ""],
	 );
}

sub restart {
}

sub undo {

}

sub getDocumentation {
}
