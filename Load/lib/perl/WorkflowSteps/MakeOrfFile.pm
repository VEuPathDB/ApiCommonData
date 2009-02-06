package ApiCommonData::Load::WorkflowSteps::MakeOrfFile;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
  my ($self, $test, $undo) = @_;

  my $seqFile = $self->getParamValue('seqFile');
  my $minPepLength = $self->getParamValue('minPepLength');
  my $outputFile = $self->getParamValue('outputFile');

  my $localDataDir = $self->getLocalDataDir();

  my $cmd = <<"EOF";
orfFinder --dataset  $localDataDir/$seqFile \\
--minPepLength $minPepLength \\
--outFile $localDataDir/$outputFile
EOF

  if ($test) {
    $self->testInputFile('seqFile', "$localDataDir/$seqFile");
    $self->runCmd(0,"echo test > $localDataDir/$outputFile");
  }

  if ($undo) {
    $self->runCmd(0, "rm -f $localDataDir/$outputFile");
  } else {
    $self->runCmd($test,$cmd);
  }
}

sub getParamDeclaration {
  return (
	  'inputFile',
	  'minPepLength',
	  'outputFile',
	 );
}

sub getConfigDeclaration {
  return (
	  # [name, default, description]
	 );
}

