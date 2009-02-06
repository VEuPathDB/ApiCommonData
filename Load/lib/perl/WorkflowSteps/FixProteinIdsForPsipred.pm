package ApiCommonData::Load::WorkflowSteps::FixProteinIdsForPsipred;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test, $undo) = @_;

  my $inputProteinsFile = $self->getParamValue('inputProteinsFile');
  my $outputProteinsFile = $self->getParamValue('outputProteinsFile');

  my $fix = 's/^(\S+)-(\d)/$1_$2/g';

  my $localDataDir = $self->getLocalDataDir();

  my $cmd = "cat $localDataDir/$inputProteinsFile | perl -pe '$fix' > $localDataDir/$outputProteinsFile";

  if ($test){
    $self->testInputFile('inputProteinsFile', "$localDataDir/$inputProteinsFile");
    $self->runCmd(0,"echo test > $localDataDir/$outputProteinsFile");
  }

  if ($undo) {
    $self->runCmd(0, "rm -f $localDataDir/$outputProteinsFile");
  } else {
    $self->runCmd($test,$cmd);
  }
}


sub getParamsDeclaration {
  return ('inputProteinsFile',
	  'outputProteinsFile'
	 );
}


sub getConfigDeclaration {
  return (
	  # [name, default, description]
 	 );
}


