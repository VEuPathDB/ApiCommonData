package ApiCommonData::Load::WorkflowSteps::FixMercatorOffsetsInGFF;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test) = @_;

  my $inGFFFile = $self->getParamValue('inputFile');
  my $inFastaFile = $self->getParamValue('fsaFile');
  my $outputFile = $self->getParamValue('outputFile');

  my $localDataDir = $self->getLocalDataDir();

  my $args = "--f $localDataDir/$inFastaFile --g $localDataDir/$inGFFFile --o $outFile";

  if ($test){
    $self->runCmd(0,'echo test > $localDataDir/$outputFile');
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
