package ApiCommonData::Load::WorkflowSteps::FindTandemRepeats;

@ISA = (GUS::Workflow::WorkflowStepInvoker);

use strict;
use GUS::Workflow::WorkflowStepInvoker;


sub run {
  my ($self, $test) = @_;

  my $seqFile = $self->getParamValue('inputFile');
  
  my $repeatFinderArgs = $self->getParamValue('repeatFinderArgs');

  $repeatFinderArgs =~ s/\s+/\./g;

  my $outputDir = $self->getParamValue('outputDir');

  my $trfPath = $self->getConfig('trfPath');

  my $workingDir = $self->runCmd(0,'pwd');

  $self->runCmd(0, "chdir $outputDir") if -d $outputDir;

  my $cmd = "${trfPath}/trf400 $seqFile $repeatFinderArgs -d";

  if ($test) {

      $self->runCmd(0,"test > $outputDir/$seqFile.$repeatFinderArgs.dat");

  } else {
      
      $self->runCmd($test,$cmd); 
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
     ['inputFile', "", ""],
     ['repeatFinderArgs', "", ""],
     ['outputDir',"",""],
    );
  return @properties;
}

sub getDocumentation {
}
