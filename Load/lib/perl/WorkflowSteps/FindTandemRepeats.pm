package ApiCommonData::Load::WorkflowSteps::FindTandemRepeats;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
  my ($self, $test) = @_;

  my $seqFile = $self->getParamValue('seqFile');
  
  my $repeatFinderArgs = $self->getParamValue('repeatFinderArgs');

  $repeatFinderArgs =~ s/\s+/\./g;

  my $outputFile = $self->getParamValue('outputFile');

  my $trfPath = $self->getConfig('trfPath');

  my $workingDir = $self->runCmd(0,'pwd');

  my $outputDir = " $workingDir/temp";

  $self->runCmd(0, "mkdir -p $outputDir") if ! -d $outputDir;

  $self->runCmd(0, "chdir $outputDir") if -d $outputDir;

  my $cmd = "${trfPath}/trf400 $seqFile $repeatFinderArgs -d";

  if ($test) {

      $self->runCmd(0,"echo hello > $outputFile");

  } else {
      
      $self->runCmd($test,$cmd); 

      $self->runCmd($test,"mv $outputDir/$seqFile.$repeatFinderArgs.dat $outputFile"); 

      $self->runCmd($test,"rm -fr $outputDir"); 
  }
  
  $self->runCmd(0, "chdir $workingDir");
}


sub restart {
}

sub undo {

}

sub getConfigDeclaration {
  my @properties = 
    (
     # [name, default, description]
     ['trfPath', "", ""],
    );
  return @properties;
}

sub getParamDeclaration {
  my @properties = 
    (
     # [name, default, description]
     ['inputFile'],
     ['repeatFinderArgs'],
     ['outputFile'],
    );
  return @properties;
}

sub getDocumentation {
}
