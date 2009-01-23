package ApiCommonData::Load::WorkflowSteps::FindTandemRepeats;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
  my ($self, $test) = @_;

  my $seqsFile = $self->getParamValue('seqsFile');
  my $repeatFinderArgs = $self->getParamValue('repeatFinderArgs');
  my $outputFile = $self->getParamValue('outputFile');

  my $trfPath = $self->getConfig('trfPath');

  my $stepDir = $self->getStepDir();

  my $localDataDir = $self->getLocalDataDir();

  my $cmd = "${trfPath}/trf400 $localDataDir/$seqsFile $repeatFinderArgs -d 2>> $stepDir/command.log";
 
  $repeatFinderArgs =~ s/\s+/\./g;

  if ($test) {
    $self->testInputFile('seqsFile', "$localDataDir/$seqsFile");

    $self->runCmd(0,"echo test > $localDataDir/$outputFile");

  }
  $self->runCmd($test, $cmd);
  $self->runCmd($test, "mv $stepDir/$seqsFile.$repeatFinderArgs.dat $localDataDir/$outputFile");
}

sub getParamsDeclaration {
  return (
	  'seqsFile',
	  'repeatFinderArgs',
	  'outputFile',
	 );
}

sub getConfigDeclaration {
  return (
	  # [name, default, description]
	  ['trfPath', "", ""],
	 );
}

sub getDocumentation {
}

sub restart {
}

sub undo {

}
