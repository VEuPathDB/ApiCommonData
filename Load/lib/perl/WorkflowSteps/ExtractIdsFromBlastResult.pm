package ApiCommonData::Load::WorkflowSteps::ExtractIdsFromBlastResult;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
  my ($self, $test) = @_;

  my $inputFile = $self->getParamValue('inputFile');

  my $idType = $self->getParamValue('idType');

  my $outputFile = $self->getParamValue('outputFile');

  $self->runCmd(0,"gunzip -f $inputFile") if ($inputFile=~ /\.gz/);

  my $cmd = "makeIdFileFromBlastSimOutput --$idType --subject --blastSimFile $inputFile --outFile $outputFile";

  if ($test) {

      $self->runCmd(0,"echo hello > $outputFile");

  } else {

      $self->runCmd($test,$cmd);

  }

}

sub restart {
}

sub undo {

}

sub getConfigDeclaration {
  my @properties = 
    (
    );
  return @properties;
}

sub getParamDeclaration {
  my @properties = 
    (
     ['idType',
      'outputFile',
      'inputFile',
     ]
    );
  return @properties;
}

sub getDocumentation {
}
