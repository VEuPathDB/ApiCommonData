package ApiCommonData::Load::WorkflowSteps::MakeOrfFile;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
  my ($self, $test) = @_;

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
      $self->runCmd(0,"echo test > $localDataDir/$outputFile");
  }
  $self->runCmd($test,$cmd);
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

sub restart {
}

sub undo {

}

sub getDocumentation {
}
