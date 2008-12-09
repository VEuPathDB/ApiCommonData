package ApiCommonData::Load::WorkflowSteps::RunTmhmm;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
  my ($self, $test) = @_;

  my $proteinsFile = $self->getParamValue('proteinsFile');
  my $outputFile = $self->getParamValue('outputFile');

  my $binPath = $self->getConfig('binPath');

  my $localDataDir = $self->getLocalDataDir();

  my $cmd = "runTMHMM -binPath $binPath -short -seqFile $localDataDir/$proteinsFile -outFile $localDataDir/$outputFile";

  if ($test) {
      $self->testInputFile('proteinsFile', "$localDataDir/$proteinsFile");
      $self->runCmd(0,"echo test > $localDataDir/$outputFile");
  }
  $self->runCmd($test,$cmd);
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
	  ['path', "", ""],
	 );
}

sub restart {
}

sub undo {

}

sub getDocumentation {
}
