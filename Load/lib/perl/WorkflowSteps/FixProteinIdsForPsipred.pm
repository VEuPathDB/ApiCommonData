package ApiCommonData::Load::WorkflowSteps::FixProteinIdsForPsipred;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
 	my ($self, $test) = @_;
	
	my $inputfile = $self->getParamValue('inputProteinsFile');
	my $outputfile = $self->getParamValue('outputProteinsFile');
	
	$outputFile =~ s/(\S+)\.(\S+)/$1/;
    	$outputFile .= "Psipred.".$2;

    	my $fix = 's/^(\S+)-(\d)/$1_$2/g';
	
	my $cmd = "cat $inputfile | perl -pe '$fix' > $outputFile";

	if ($test){
	      $self->runCmd(0,'echo test > $outputFile');
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
