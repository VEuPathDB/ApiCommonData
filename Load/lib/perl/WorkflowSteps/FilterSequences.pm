package ApiCommonData::Load::WorkflowSteps::FilterSequences;

@ISA = (GUS::Workflow::WorkflowStepInvoker);

use strict;
use GUS::Workflow::WorkflowStepInvoker;


sub run {
  my ($self, $test) = @_;

  my $seqFile = $self->getParamValue('seqFile');

  my $seqfilesDir = $self->getParamValue('seqfilesDir');

  my $outputFile = $self->getParamValue('outputFile');
  
  my $filterDir = $self->getParamValue('$filterDir');

  my $genomeName = $self->getParamValue('genomeName'); 
 
  my $filterType = $self->getParamValue('filterType'); 

  my $opt = $self->getParamValue('opt');

  my $dataDir = $self->getGlobalConfig('dataDir');
  
  my $projectName = $self->getGlobalConfig('projectName');
 
  my $projectVersion = $self->getGlobalConfig('projectVersion');

  my $blastDir = $self->getConfig('wuBlastPath');

  my $filter = "$blastDir/$projectName/$projectVersion/$filterDir/$filterType";

  my $logFile = "$dataDir/$projectName/$projectVersion/logs/$genomeName/${seqFile}.$filterType.log";

  my $input = "$dataDir/$projectName/$projectVersion/primary/data/$genomeName/$seqfilesDir/$seqFile";

  my $output = "$dataDir/$projectName/$projectVersion/primary/data/$genomeName/$seqfilesDir/$outputFile";

  if ($test) {
      $self->runCmd(0,"test > $output");
  } else {
      self->runCmd($test,"$filter $input $opt > $output 2>> $logFile"); 
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
1
