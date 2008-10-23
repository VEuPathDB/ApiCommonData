package ApiCommonData::Load::WorkflowSteps::FindTandemRepeats;

@ISA = (GUS::Workflow::WorkflowStepInvoker);

use strict;
use GUS::Workflow::WorkflowStepInvoker;


sub run {
  my ($self, $test) = @_;

  my $seqFile = $self->getParamValue('seqFile');
  
  my $seqfilesDir = $self->getParamValue('$seqfilesDir');

  my $repeatFinderArgs = $self->getParamValue('$repeatFinderArgs');

  my $genomeName = $self->getParamValue('genomeName'); 

  my $trfPath = $self->getConfig('trfPath');

  my $dataDir = $self->getGlobalConfig('dataDir');
  
  my $projectName = $self->getGlobalConfig('projectName');
 
  my $projectVersion = $self->getGlobalConfig('projectVersion');

  my $trfDir = "$dataDir/$projectName/$projectVersion/data/$genomeName/trf";

  my $logFile = "$dataDir/$projectName/$projectVersion/logs/$genomeName/run${seqFile}.TRF.log";

  $self->runCmd(0, "mkdir -p $trfDir") if $trfDir;

  $self->runCmd(0, "chdir $trfDir");

  my $cmd = "${trfPath}/trf400 ${dataDir}/$projectName/$projectVersion/data/$genomeName/$seqfilesDir/$seqFile $repeatFinderArgs -d > $logFile";
  
  $self->runCmd($test,$cmd);
  
  $self->runCmd(0, "chdir ${dataDir}/$projectName/$projectVersion/data/$genomeName");
}


sub restart {
}

sub undo {

}

sub getConfigDeclaration {
  my @properties = 
    (
     # [name, default, description]
     ['seqFile', "", ""],
     ['seqfilesDir', "", ""],
     ['repeatFinderArgs', "", ""],
     ['genomeName',"",""],
     ['trfPath',"",""],
    );
  return @properties;
}

sub getDocumentation {
}
