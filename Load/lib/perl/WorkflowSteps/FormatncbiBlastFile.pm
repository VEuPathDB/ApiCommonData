package ApiCommonData::Load::WorkflowSteps::formatncbiBlastFile;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
 	my ($self, $test) = @_;
	
	my $inputFile = $self->getParamValue('inputFile');
	my $arg = $self->getParamValue('formatterArgs');
	my $blastBinDir = $self->getConfig('ncbiBlastPath');
	
	$self->runcmd($test,"$blastBinDir/formatdb -i $inputFile -p $arg");
	
}

sub getParamsDeclaration {
  return ('inputFile',
	  'formatterArgs'
	 );
}



sub getConfigDeclaration {
  return (
	  # [name, default, description]
 	    ['ncbiBlastPath', "", ""],
	 );
}

sub getDocumentation {
}

sub restart {
}

sub undo {

}
