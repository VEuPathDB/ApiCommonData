package ApiCommonData::Load::WorkflowSteps::RunTmhmm;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
  my ($self, $test) = @_;

  my $outputFile = $self->getParamValue('outputFile');
  my $proteinsFile = $self->getParamValue('proteinsFile');
  my $binPath = $self->getConfig('path');

  my $localDataDir = $self->getLocalDataDir();

  my $cmd = "runTMHMM -binPath $binPath -short -seqFile $localDataDir/$proteinsFile -outFile $localDataDir/$outputFile";

  if ($test) {
      $self->runCmd(0,"echo test > $localDataDir/$outputFile");
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
