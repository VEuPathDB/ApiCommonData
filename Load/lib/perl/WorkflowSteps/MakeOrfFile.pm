package ApiCommonData::Load::WorkflowSteps::MakeOrfFile;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
  my ($self, $test) = @_;

  my $seqFile = $self->getParamValue('seqFile');
  
  my $minPepLength = $self->getParamValue('minPepLength');

  my $outputFile = $self->getParamValue('outputFile');

   my $cmd = <<"EOF";
orfFinder --dataset  $seqFile \\
--minPepLength $minPepLength \\
--outFile $outputFile
EOF

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
    );
  return @properties;
}

sub getParamDeclaration {
  my @properties = 
    (
     # [name, default, description]
     ['inputFile'],
     ['minPepLength'],
     ['outputFile'],
    );
  return @properties;
}

sub getDocumentation {
}
