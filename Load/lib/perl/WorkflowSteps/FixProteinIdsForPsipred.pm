package ApiCommonData::Load::WorkflowSteps::FixProteinIdsForPsipred;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test) = @_;

  my $inputProteinsFile = $self->getParamValue('inputProteinsFile');
  my $outputProteinsFile = $self->getParamValue('outputProteinsFile');

  my $fix = 's/^(\S+)-(\d)/$1_$2/g';

  my $cmd = "cat $inputProteinsFile | perl -pe '$fix' > $outputProteinsFile";

  if ($test){
    $self->runCmd(0,'echo test > $outputProteinsFile');
  }else{
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

sub getDocumentation {
}

sub restart {
}

sub undo {

}
