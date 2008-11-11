package ApiCommonData::Load::WorkflowSteps::ExtractIdsFromBlastResult;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
  my ($self, $test) = @_;

  my $inputFile = $self->getParamValue('inputFile');
  my $idType = $self->getParamValue('idType');
  my $outputFile = $self->getParamValue('outputFile');

  # i don't think this is needed, as the cmd handles it -steve
  #  $self->runCmd($test,"gunzip -f $inputFile") if ($inputFile=~ /\.gz/);

  my $cmd = "makeIdFileFromBlastSimOutput --$idType --subject --blastSimFile $inputFile --outFile $outputFile";

  if ($test) {

      $self->runCmd(0,"echo test > $outputFile");

  } else {

      $self->runCmd($test,$cmd);

  }

}

sub getParamsDeclaration {
  return (
	  'idType',
	  'outputFile',
	  'inputFile',
	 );
}

sub getConfigDeclaration {
  return
    (
    );
}

sub restart {
}

sub undo {

}

sub getDocumentation {
}
