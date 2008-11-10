package ApiCommonData::Load::WorkflowSteps::RunTmhmm;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
  my ($self, $test) = @_;

  my $outputFile = $self->getParamValue('outputFile');

  my $proteinsFile = $self->getParamValue('proteinsFile');

  my $binPath = $self->getConfig('path');

  my $cmd = "runTMHMM -binPath $binPath -short -seqFile $proteinsFile -outFile $outputFile";

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
     # [name, default, description]
     ['binPath', "", ""],
    );
  return @properties;
}

sub getParamDeclaration {
  my @properties = 
    (
     ['proteinsFile'],
     ['outputFile'],
    );
  return @properties;
}

sub getDocumentation {
}
