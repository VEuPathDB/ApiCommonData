package ApiCommonData::Load::WorkflowSteps::FixMercatorOffsetsInGFF;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
	my ($self, $test) = @_;

	my $inGFFFile = $self->getParamValue('inputFile');
	my $inFastaFile = $self->getParamValue('fsaFile');
	my $outFile = $self->getParamValue('outputFile');
	
	my $args = "--f $inFastaFile --g $inGFFFile --o $outFile";

	 if ($test){
	      $self->runCmd(0,'echo test > $outFile');
	  }else{
	      $self->runCmd($test,"fixMercatorOffsetsInGFF.pl $args");
	  }
}

sub getParamsDeclaration {
  return ('inputFile',
	  'fsaFile',
	  'outputFile'
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
