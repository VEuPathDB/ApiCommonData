package ApiCommonData::Load::WorkflowSteps::RunSignalP;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
  my ($self, $test) = @_;

  my $proteinsFile = $self->getParamValue('proteinsFile');
  my $outputFile = $self->getParamValue('outputFile');
  my $options = $self->getParamValue('options');

  my $binPath = $self->getConfig('path');

  my $localDataDir = $self->getLocalDataDir();

  my $cmd = "runSignalP --binPath $binPath  --options '$options' --seqFile $localDataDir/$proteinsFile --outFile $localDataDir/$outputFile";

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
	  'options',
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
